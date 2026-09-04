-- RevenueCat authority for Mosaic V3. Store data is mirrored locally only by
-- service-role functions; clients can read their own snapshot but cannot write it.

alter table public.mosaic_v3_mosaics
  add column access_source text not null default 'free'
  check (access_source in ('free', 'organizer_plus', 'event_pass'));

create or replace function private.v3_prevent_mosaic_access_source_change()
returns trigger language plpgsql set search_path = '' as $$
begin
  if old.access_source <> new.access_source then raise exception 'mosaic_access_source_is_immutable' using errcode='P0001'; end if;
  return new;
end;
$$;
create trigger mosaics_immutable_access_source before update of access_source on public.mosaic_v3_mosaics
for each row execute function private.v3_prevent_mosaic_access_source_change();

create table public.mosaic_v3_billing_accounts (
  user_id uuid primary key references public.mosaic_v3_profiles(id) on delete cascade,
  revenuecat_app_user_id text not null unique,
  plus_active boolean not null default false,
  subscription_state text not null default 'none'
    check (subscription_state in ('none','trialing','active','grace_period','billing_issue','cancelled','expired')),
  product_id text,
  expires_at timestamptz,
  will_renew boolean not null default false,
  pass_balance integer not null default 0 check (pass_balance >= 0),
  synchronized_at timestamptz,
  reconciliation_required boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (revenuecat_app_user_id = lower(user_id::text))
);

create table private.mosaic_v3_revenuecat_events (
  event_id text primary key,
  payload_hash text not null,
  event_type text not null,
  app_user_id text,
  received_at timestamptz not null default now()
);

create table private.mosaic_v3_pass_redemptions (
  request_id uuid primary key,
  user_id uuid not null references public.mosaic_v3_profiles(id) on delete cascade,
  payload jsonb not null,
  state text not null check (state in ('reserved','completed','failed')),
  mosaic_id uuid references public.mosaic_v3_mosaics(id) on delete set null,
  idempotency_key text not null unique,
  failure_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (request_id, user_id)
);

alter table public.mosaic_v3_billing_accounts enable row level security;
revoke all on public.mosaic_v3_billing_accounts from anon, authenticated;
grant select on public.mosaic_v3_billing_accounts to authenticated;
create policy billing_accounts_read_own on public.mosaic_v3_billing_accounts
  for select to authenticated using (user_id = (select auth.uid()));
revoke all on private.mosaic_v3_revenuecat_events, private.mosaic_v3_pass_redemptions from public, anon, authenticated;

create or replace function private.v3_plus_active(target_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((
    select b.plus_active and (b.expires_at is null or b.expires_at > now())
    from public.mosaic_v3_billing_accounts b where b.user_id = target_user
  ), false);
$$;

create or replace function private.v3_capabilities(source text)
returns jsonb language sql immutable set search_path = '' as $$
  select case when source in ('organizer_plus','event_pass') then
    jsonb_build_object(
      'canCreateMultipleActiveMosaics', true,
      'maximumTileGoal', 100,
      'maximumShotLimit', 36,
      'availableFilmLooks', jsonb_build_array('sunwashed','garden','afterglow')
    ) else jsonb_build_object(
      'canCreateMultipleActiveMosaics', false,
      'maximumTileGoal', 25,
      'maximumShotLimit', 12,
      'availableFilmLooks', jsonb_build_array('sunwashed')
    ) end;
$$;

create or replace function private.v3_draft_requires_premium(payload jsonb)
returns boolean language sql immutable set search_path = '' as $$
  select coalesce((payload->>'goal')::integer, 0) > 25
      or coalesce((payload->>'shotLimit')::integer, 0) > 12
      or coalesce(payload->>'filmLookID', '') <> 'sunwashed';
$$;

create or replace function private.v3_summary_json(m public.mosaic_v3_mosaics)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', m.id, 'name', m.name, 'communityName', m.community_name, 'description', m.description,
    'startAt', m.start_at, 'revealAt', m.reveal_at, 'goal', m.tile_goal,
    'contributionCount', (select count(*) from public.mosaic_v3_kindness_contributions c where c.mosaic_id = m.id),
    'photoCount', (select count(*) from public.mosaic_v3_event_photos p where p.mosaic_id = m.id and p.state = 'eligible'),
    'filmLookID', m.film_look_id, 'shotLimit', m.shot_limit,
    'artwork', case when now() >= m.reveal_at then private.v3_artwork_json(a) else private.v3_sealed_artwork_json() end,
    'isCreator', m.creator_id = auth.uid(),
    'accessSource', m.access_source,
    'premiumCapabilities', private.v3_capabilities(m.access_source)
  ) from public.mosaic_v3_artwork_catalog a where a.id = m.artwork_id;
$$;

create or replace function private.v3_create_mosaic_for_user(payload jsonb, target_user uuid, source text)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare m public.mosaic_v3_mosaics; activity jsonb; code text;
begin
  if target_user is null or not exists(select 1 from public.mosaic_v3_profiles where id = target_user) then
    raise exception 'display_name_required' using errcode = 'P0001';
  end if;
  if source not in ('free','organizer_plus','event_pass') then raise exception 'invalid_access_source' using errcode='P0001'; end if;
  if jsonb_array_length(coalesce(payload->'activities','[]'::jsonb)) < 1 then raise exception 'activity_required' using errcode='P0001'; end if;
  if (payload->>'goal')::integer not in (9,16,25,36,49,64,81,100)
     or (payload->>'shotLimit')::integer not in (12,24,36)
     or payload->>'filmLookID' not in ('sunwashed','garden','afterglow') then
    raise exception 'invalid_mosaic_options' using errcode='P0001';
  end if;
  if source = 'free' and private.v3_draft_requires_premium(payload) then raise exception 'premium_required' using errcode='P0001'; end if;
  code := upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
  insert into public.mosaic_v3_mosaics(
    creator_id,name,community_name,description,invitation_code,artwork_id,
    film_look_id,shot_limit,tile_goal,start_at,reveal_at,access_source
  ) values (
    target_user,btrim(payload->>'name'),btrim(payload->>'communityName'),btrim(coalesce(payload->>'description','')),
    code,(payload->>'artworkID')::uuid,payload->>'filmLookID',(payload->>'shotLimit')::integer,
    (payload->>'goal')::integer,(payload->>'startAt')::timestamptz,(payload->>'revealAt')::timestamptz,source
  ) returning * into m;
  insert into public.mosaic_v3_members(mosaic_id,profile_id,role) values(m.id,target_user,'creator');
  for activity in select value from jsonb_array_elements(payload->'activities') loop
    insert into public.mosaic_v3_kindness_activities(mosaic_id,title,purpose,sort_order)
    values(m.id,btrim(activity->>'title'),btrim(coalesce(activity->>'purpose','')),(activity->>'sortOrder')::integer);
  end loop;
  return m.id;
end;
$$;

create or replace function public.v3_create_mosaic(payload jsonb)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := auth.uid(); source text; mosaic_id uuid; m public.mosaic_v3_mosaics;
begin
  if uid is null then raise exception 'account_required' using errcode='P0001'; end if;
  if private.v3_plus_active(uid) then
    source := 'organizer_plus';
  else
    source := 'free';
    if private.v3_draft_requires_premium(payload) then raise exception 'premium_required' using errcode='P0001'; end if;
    if exists(select 1 from public.mosaic_v3_mosaics x where x.creator_id=uid and now()<x.reveal_at) then
      raise exception 'free_creation_limit' using errcode='P0001';
    end if;
  end if;
  mosaic_id := private.v3_create_mosaic_for_user(payload,uid,source);
  select * into strict m from public.mosaic_v3_mosaics where id=mosaic_id;
  return private.v3_event_json(m);
end;
$$;

create or replace function public.v3_billing_snapshot()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := auth.uid(); b public.mosaic_v3_billing_accounts;
begin
  if uid is null then raise exception 'account_required' using errcode='42501'; end if;
  select * into b from public.mosaic_v3_billing_accounts where user_id=uid;
  return jsonb_build_object(
    'plusActive', coalesce(b.plus_active and (b.expires_at is null or b.expires_at>now()),false),
    'subscriptionState', coalesce(b.subscription_state,'none'),
    'productID', b.product_id,
    'expiresAt', b.expires_at,
    'willRenew', coalesce(b.will_renew,false),
    'passBalance', coalesce(b.pass_balance,0),
    'synchronizedAt', b.synchronized_at
  );
end;
$$;

create or replace function public.v3_internal_sync_billing(
  "userID" uuid, "plusActive" boolean, "subscriptionState" text,
  "productID" text, "expiresAt" timestamptz, "willRenew" boolean, "passBalance" integer
) returns boolean language plpgsql volatile security definer set search_path = '' as $$
begin
  if "subscriptionState" not in ('none','trialing','active','grace_period','billing_issue','cancelled','expired')
     or "passBalance" < 0 then raise exception 'invalid_billing_snapshot' using errcode='P0001'; end if;
  insert into public.mosaic_v3_billing_accounts(user_id,revenuecat_app_user_id,plus_active,subscription_state,product_id,expires_at,will_renew,pass_balance,synchronized_at,reconciliation_required)
  values("userID",lower("userID"::text),"plusActive","subscriptionState","productID","expiresAt","willRenew","passBalance",now(),false)
  on conflict(user_id) do update set
    plus_active=excluded.plus_active,subscription_state=excluded.subscription_state,product_id=excluded.product_id,
    expires_at=excluded.expires_at,will_renew=excluded.will_renew,pass_balance=excluded.pass_balance,
    synchronized_at=now(),reconciliation_required=false,updated_at=now();
  return true;
end;
$$;

create or replace function public.v3_internal_begin_pass_redemption("requestID" uuid,"userID" uuid,payload jsonb)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare existing private.mosaic_v3_pass_redemptions; account public.mosaic_v3_billing_accounts; mid uuid;
begin
  select * into existing from private.mosaic_v3_pass_redemptions where request_id="requestID";
  if existing.request_id is not null then
    if existing.user_id<>"userID" or existing.payload<>payload then raise exception 'request_id_conflict' using errcode='23505'; end if;
    return jsonb_build_object('state',existing.state,'mosaicID',existing.mosaic_id,'shouldDebit',existing.state='reserved','idempotencyKey',existing.idempotency_key);
  end if;
  if private.v3_plus_active("userID") then
    mid := private.v3_create_mosaic_for_user(payload,"userID",'organizer_plus');
    insert into private.mosaic_v3_pass_redemptions(request_id,user_id,payload,state,mosaic_id,idempotency_key)
    values("requestID","userID",payload,'completed',mid,'mosaic-pass-'||"requestID"::text);
    return jsonb_build_object('state','completed','mosaicID',mid,'shouldDebit',false,'idempotencyKey','mosaic-pass-'||"requestID"::text);
  end if;
  select * into account from public.mosaic_v3_billing_accounts where user_id="userID" for update;
  if account.user_id is null or account.pass_balance<1 then raise exception 'insufficient_pass' using errcode='P0001'; end if;
  update public.mosaic_v3_billing_accounts set pass_balance=pass_balance-1,updated_at=now() where user_id="userID";
  insert into private.mosaic_v3_pass_redemptions(request_id,user_id,payload,state,idempotency_key)
  values("requestID","userID",payload,'reserved','mosaic-pass-'||"requestID"::text);
  return jsonb_build_object('state','reserved','mosaicID',null,'shouldDebit',true,'idempotencyKey','mosaic-pass-'||"requestID"::text);
end;
$$;

create or replace function public.v3_internal_complete_pass_redemption("requestID" uuid,"userID" uuid)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare redemption private.mosaic_v3_pass_redemptions; mid uuid;
begin
  select * into strict redemption from private.mosaic_v3_pass_redemptions where request_id="requestID" and user_id="userID" for update;
  if redemption.state='completed' then return redemption.mosaic_id; end if;
  if redemption.state<>'reserved' then raise exception 'pass_redemption_failed' using errcode='P0001'; end if;
  mid := private.v3_create_mosaic_for_user(redemption.payload,"userID",'event_pass');
  update private.mosaic_v3_pass_redemptions set state='completed',mosaic_id=mid,updated_at=now() where request_id="requestID";
  return mid;
end;
$$;

create or replace function public.v3_internal_fail_pass_redemption("requestID" uuid,"userID" uuid,reason text)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
declare changed integer;
begin
  update private.mosaic_v3_pass_redemptions set state='failed',failure_reason=left(reason,500),updated_at=now()
  where request_id="requestID" and user_id="userID" and state='reserved';
  get diagnostics changed = row_count;
  if changed=1 then
    update public.mosaic_v3_billing_accounts set pass_balance=pass_balance+1,reconciliation_required=true,updated_at=now() where user_id="userID";
  end if;
  return changed=1;
end;
$$;

create or replace function public.v3_internal_record_revenuecat_event(
  "eventID" text,"payloadHash" text,"eventType" text,"appUserID" text
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare prior private.mosaic_v3_revenuecat_events; uid uuid;
begin
  select * into prior from private.mosaic_v3_revenuecat_events where event_id="eventID";
  if prior.event_id is not null then
    if prior.payload_hash<>"payloadHash" then raise exception 'event_id_hash_conflict' using errcode='23505'; end if;
    return jsonb_build_object('duplicate',true);
  end if;
  insert into private.mosaic_v3_revenuecat_events(event_id,payload_hash,event_type,app_user_id)
  values("eventID","payloadHash","eventType",lower("appUserID"));
  begin uid := lower("appUserID")::uuid; exception when invalid_text_representation then uid := null; end;
  if uid is not null then
    insert into public.mosaic_v3_billing_accounts(user_id,revenuecat_app_user_id,reconciliation_required)
    select uid,lower(uid::text),true where exists(select 1 from public.mosaic_v3_profiles where id=uid)
    on conflict(user_id) do update set reconciliation_required=true,updated_at=now();
  end if;
  return jsonb_build_object('duplicate',false,'reconcile',uid is not null);
end;
$$;

revoke all on function private.v3_prevent_mosaic_access_source_change() from public,anon,authenticated;
revoke all on function private.v3_plus_active(uuid) from public,anon,authenticated;
revoke all on function private.v3_capabilities(text) from public,anon,authenticated;
revoke all on function private.v3_draft_requires_premium(jsonb) from public,anon,authenticated;
revoke all on function private.v3_summary_json(public.mosaic_v3_mosaics) from public,anon,authenticated;
revoke all on function private.v3_create_mosaic_for_user(jsonb,uuid,text) from public,anon,authenticated;
revoke all on function public.v3_internal_sync_billing(uuid,boolean,text,text,timestamptz,boolean,integer) from public,anon,authenticated;
revoke all on function public.v3_internal_begin_pass_redemption(uuid,uuid,jsonb) from public,anon,authenticated;
revoke all on function public.v3_internal_complete_pass_redemption(uuid,uuid) from public,anon,authenticated;
revoke all on function public.v3_internal_fail_pass_redemption(uuid,uuid,text) from public,anon,authenticated;
revoke all on function public.v3_internal_record_revenuecat_event(text,text,text,text) from public,anon,authenticated;
grant execute on function public.v3_create_mosaic(jsonb), public.v3_billing_snapshot() to authenticated;
grant execute on function public.v3_internal_sync_billing(uuid,boolean,text,text,timestamptz,boolean,integer) to service_role;
grant execute on function public.v3_internal_begin_pass_redemption(uuid,uuid,jsonb) to service_role;
grant execute on function public.v3_internal_complete_pass_redemption(uuid,uuid) to service_role;
grant execute on function public.v3_internal_fail_pass_redemption(uuid,uuid,text) to service_role;
grant execute on function public.v3_internal_record_revenuecat_event(text,text,text,text) to service_role;
