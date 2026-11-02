-- First registered Supabase Auth user becomes the initial review moderator.
-- Run once in Supabase SQL Editor. Re-running is safe and does not replace existing admins.
begin;

create table if not exists public.site_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  assigned_at timestamptz not null default now()
);
alter table public.site_admins enable row level security;
drop policy if exists "Admins can read own role" on public.site_admins;
create policy "Admins can read own role" on public.site_admins
  for select to authenticated using (user_id = auth.uid());
grant select on public.site_admins to authenticated;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.site_admins where user_id = auth.uid()
  );
$$;
revoke all on function public.is_site_admin() from public, anon;
grant execute on function public.is_site_admin() to authenticated;

insert into public.site_admins (user_id)
select id from auth.users
order by created_at asc, id asc
limit 1
on conflict (user_id) do nothing;

drop policy if exists "Admins can read all building reviews" on public.building_reviews;
create policy "Admins can read all building reviews" on public.building_reviews
  for select to authenticated using (public.is_site_admin());
drop policy if exists "Admins can update review status" on public.building_reviews;
create policy "Admins can update review status" on public.building_reviews
  for update to authenticated
  using (public.is_site_admin())
  with check (public.is_site_admin());
grant update (status) on public.building_reviews to authenticated;

commit;
