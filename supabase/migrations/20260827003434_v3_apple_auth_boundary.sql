-- Additive authentication boundary for Mosaic V3.
-- This deliberately does not modify the populated legacy public.profiles table.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists public.mosaic_v3_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (
    char_length(display_name) between 2 and 40
    and display_name = btrim(display_name)
    and display_name !~ '[[:cntrl:]]'
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.mosaic_v3_profiles enable row level security;
revoke all on table public.mosaic_v3_profiles from public, anon, authenticated;

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
  ) then
    raise exception using errcode = '42501', message = 'apple_account_required';
  end if;

  if not exists (
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
  from public.mosaic_v3_profiles as profile
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
  saved_profile public.mosaic_v3_profiles;
begin
  if cleaned_name is null
    or char_length(cleaned_name) not between 2 and 40
    or cleaned_name ~ '[[:cntrl:]]'
  then
    raise exception using errcode = '22023', message = 'invalid_display_name';
  end if;

  insert into public.mosaic_v3_profiles as profile (id, display_name)
  values (account_id, cleaned_name)
  on conflict (id) do update
    set display_name = excluded.display_name,
        updated_at = now()
  returning profile.* into saved_profile;

  return to_jsonb(saved_profile);
end;
$$;

create or replace function public.v3_auth_delete_account()
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  account_id uuid := private.v3_require_apple_user();
begin
  delete from auth.users where id = account_id;
  return found;
end;
$$;

revoke all on function public.v3_auth_profile() from public, anon;
revoke all on function public.v3_auth_save_profile(text) from public, anon;
revoke all on function public.v3_auth_delete_account() from public, anon;
grant execute on function public.v3_auth_profile() to authenticated;
grant execute on function public.v3_auth_save_profile(text) to authenticated;
grant execute on function public.v3_auth_delete_account() to authenticated;

comment on table public.mosaic_v3_profiles is
  'Mosaic V3 display profiles, accessible only through Apple-account-validated RPCs.';
