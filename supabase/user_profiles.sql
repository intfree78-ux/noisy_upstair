create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text not null default '',
  avatar_url text,
  provider text not null default 'email',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.users enable row level security;
revoke all on public.users from anon, authenticated;
grant select on public.users to authenticated;

drop policy if exists "Users can read their own profile" on public.users;
create policy "Users can read their own profile"
on public.users for select
to authenticated
using (auth.uid() = id);

create or replace function public.sync_auth_user_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.users (id, email, display_name, avatar_url, provider, created_at, updated_at)
  values (
    new.id,
    coalesce(nullif(new.email, ''), nullif(new.raw_user_meta_data ->> 'email', '')),
    coalesce(
      nullif(btrim(new.raw_user_meta_data ->> 'name'), ''),
      nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
      nullif(btrim(new.raw_user_meta_data ->> 'nickname'), ''),
      ''
    ),
    coalesce(
      nullif(new.raw_user_meta_data ->> 'avatar_url', ''),
      nullif(new.raw_user_meta_data ->> 'picture', ''),
      nullif(new.raw_user_meta_data ->> 'profile_image', '')
    ),
    coalesce(nullif(new.raw_app_meta_data ->> 'provider', ''), 'email'),
    new.created_at,
    pg_catalog.now()
  )
  on conflict (id) do update set
    email = coalesce(excluded.email, public.users.email),
    display_name = coalesce(nullif(excluded.display_name, ''), public.users.display_name),
    avatar_url = coalesce(excluded.avatar_url, public.users.avatar_url),
    provider = excluded.provider,
    updated_at = pg_catalog.now();
  return new;
end;
$$;

revoke all on function public.sync_auth_user_profile() from public, anon, authenticated;

drop trigger if exists auth_user_profile_insert on auth.users;
create trigger auth_user_profile_insert
after insert on auth.users
for each row execute function public.sync_auth_user_profile();

drop trigger if exists auth_user_profile_update on auth.users;
create trigger auth_user_profile_update
after update of email, raw_user_meta_data, raw_app_meta_data on auth.users
for each row execute function public.sync_auth_user_profile();

insert into public.users (id, email, display_name, avatar_url, provider, created_at, updated_at)
select
  u.id,
  coalesce(nullif(u.email, ''), nullif(u.raw_user_meta_data ->> 'email', '')),
  coalesce(
    nullif(btrim(u.raw_user_meta_data ->> 'name'), ''),
    nullif(btrim(u.raw_user_meta_data ->> 'full_name'), ''),
    nullif(btrim(u.raw_user_meta_data ->> 'nickname'), ''),
    ''
  ),
  coalesce(
    nullif(u.raw_user_meta_data ->> 'avatar_url', ''),
    nullif(u.raw_user_meta_data ->> 'picture', ''),
    nullif(u.raw_user_meta_data ->> 'profile_image', '')
  ),
  coalesce(nullif(u.raw_app_meta_data ->> 'provider', ''), 'email'),
  u.created_at,
  pg_catalog.now()
from auth.users as u
on conflict (id) do update set
  email = coalesce(excluded.email, public.users.email),
  display_name = coalesce(nullif(excluded.display_name, ''), public.users.display_name),
  avatar_url = coalesce(excluded.avatar_url, public.users.avatar_url),
  provider = excluded.provider,
  updated_at = pg_catalog.now();
