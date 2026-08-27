-- Reconcile the temporary pre-reset Apple-auth boundary with the shipping V3
-- schema. The destructive V3 core migration owns public.profiles; authenticated
-- clients may access it only through these Apple-identity-validated RPCs.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.v3_require_apple_user()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  account_id uuid := auth.uid();
begin
  if account_id is null then
    raise exception using errcode = '42501', message = 'apple_account_required';
  end if;

  if not exists (
    select 1
    from auth.users as account
    where account.id = account_id
      and account.is_anonymous is false
      and account.deleted_at is null
  ) or not exists (
    select 1
    from auth.identities as identity
    where identity.user_id = account_id
      and identity.provider = 'apple'
  ) then
    raise exception using errcode = '42501', message = 'apple_account_required';
  end if;

  return account_id;
end;
$$;

revoke all on function private.v3_require_apple_user() from public, anon, authenticated;

do $$
begin
  if to_regclass('public.mosaic_v3_profiles') is not null then
    insert into public.profiles (id, display_name, created_at, updated_at)
    select id, display_name, created_at, updated_at
    from public.mosaic_v3_profiles
    on conflict (id) do update
      set display_name = excluded.display_name,
          updated_at = greatest(public.profiles.updated_at, excluded.updated_at);

    drop table public.mosaic_v3_profiles;
  end if;
end;
$$;

alter table public.profiles enable row level security;
revoke all on table public.profiles from public, anon, authenticated;

create or replace function public.v3_auth_profile()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  account_id uuid := private.v3_require_apple_user();
  profile_payload jsonb;
begin
  select to_jsonb(profile)
  into profile_payload
  from public.profiles as profile
  where profile.id = account_id;

  return jsonb_build_object('profile', profile_payload);
end;
$$;

create or replace function public.v3_auth_save_profile(p_display_name text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  account_id uuid := private.v3_require_apple_user();
  cleaned_name text := btrim(p_display_name);
  saved_profile public.profiles;
begin
  if cleaned_name is null
    or char_length(cleaned_name) not between 2 and 40
    or cleaned_name ~ '[[:cntrl:]]'
  then
    raise exception using errcode = '22023', message = 'invalid_display_name';
  end if;

  insert into public.profiles as profile (id, display_name)
  values (account_id, cleaned_name)
  on conflict (id) do update
    set display_name = excluded.display_name,
        updated_at = now()
  returning profile.* into saved_profile;

  return to_jsonb(saved_profile);
end;
$$;

revoke all on function public.v3_auth_profile() from public, anon;
revoke all on function public.v3_auth_save_profile(text) from public, anon;
grant execute on function public.v3_auth_profile() to authenticated;
grant execute on function public.v3_auth_save_profile(text) to authenticated;

-- Account deletion must pass through the authenticated Edge Function so the
-- RevenueCat customer record is removed before the Supabase Auth user.
revoke all on function public.v3_delete_account() from public, anon, authenticated;
drop function public.v3_delete_account();
drop function if exists public.v3_auth_delete_account();

comment on table public.profiles is
  'Mosaic V3 display profiles, writable only through Apple-account-validated RPCs.';
