create table if not exists public.residences (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  area text not null,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  created_at timestamptz not null default now()
);

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  residence_id uuid not null references public.residences(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  noise_type text not null check (
    noise_type in ('footsteps', 'music', 'construction', 'road', 'other', 'quiet')
  ),
  content text not null check (char_length(content) between 10 and 300),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

alter table public.residences enable row level security;
alter table public.reviews enable row level security;

drop policy if exists "Anyone can read residences" on public.residences;
create policy "Anyone can read residences"
on public.residences for select
to anon, authenticated
using (true);

drop policy if exists "Read approved reviews or your own" on public.reviews;
create policy "Read approved reviews or your own"
on public.reviews for select
to anon, authenticated
using (
  status = 'approved'
  or (auth.uid() is not null and author_id = auth.uid())
);

drop policy if exists "Signed-in users submit pending reviews" on public.reviews;
create policy "Signed-in users submit pending reviews"
on public.reviews for insert
to authenticated
with check (auth.uid() = author_id and status = 'pending');

grant usage on schema public to anon, authenticated;

revoke all on public.residences from anon, authenticated;
revoke all on public.reviews from anon, authenticated;

grant select on public.residences to anon, authenticated;
grant select (id, residence_id, rating, noise_type, content, status, created_at)
on public.reviews to anon, authenticated;
grant insert (residence_id, author_id, rating, noise_type, content)
on public.reviews to authenticated;
