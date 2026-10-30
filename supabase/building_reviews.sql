-- Supabase SQL Editor에서 한 번 실행하세요.
-- 동/호 정보는 private 테이블에만 저장하며 공개 후기 API에는 포함하지 않습니다.

create table if not exists public.building_reviews (
  id uuid primary key default gen_random_uuid(),
  building_id text not null check (char_length(building_id) between 1 and 200),
  building_name text not null check (char_length(building_name) between 1 and 200),
  author_id uuid not null references auth.users(id) on delete cascade,
  housing_type text check (housing_type is null or housing_type in ('아파트', '빌라', '원룸', '오피스텔')),
  rating smallint not null check (rating between 1 and 5),
  noise_type text not null check (noise_type in ('footsteps', 'music', 'construction', 'road', 'other', 'quiet')),
  content text not null check (char_length(content) between 10 and 500),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

alter table public.building_reviews add column if not exists housing_type text check (housing_type is null or housing_type in ('아파트', '빌라', '원룸', '오피스텔'));

create index if not exists building_reviews_public_lookup
  on public.building_reviews (building_id, status, created_at desc);

create table if not exists public.building_review_units (
  review_id uuid primary key references public.building_reviews(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  dong text,
  ho text,
  created_at timestamptz not null default now(),
  check (dong is null or char_length(dong) <= 30),
  check (ho is null or char_length(ho) <= 30)
);

alter table public.building_reviews enable row level security;
alter table public.building_review_units enable row level security;

drop policy if exists "Read approved building reviews or own" on public.building_reviews;
create policy "Read approved building reviews or own"
on public.building_reviews for select
to anon, authenticated
using (status = 'approved' or (auth.uid() is not null and author_id = auth.uid()));

revoke all on public.building_reviews from anon, authenticated;
grant select (id, building_id, building_name, housing_type, rating, noise_type, content, status, created_at)
on public.building_reviews to anon, authenticated;
revoke all on public.building_review_units from anon, authenticated;

create or replace function public.submit_building_review(
  p_building_id text,
  p_building_name text,
  p_housing_type text,
  p_dong text,
  p_ho text,
  p_rating integer,
  p_noise_type text,
  p_content text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_author_id uuid := auth.uid();
  v_review_id uuid;
  v_dong text := nullif(left(trim(coalesce(p_dong, '')), 30), '');
  v_ho text := nullif(left(trim(coalesce(p_ho, '')), 30), '');
begin
  if v_author_id is null then
    raise exception '로그인 후 후기를 등록할 수 있습니다.';
  end if;
  if p_building_id is null or char_length(trim(p_building_id)) not between 1 and 200 then
    raise exception '건물 정보를 확인할 수 없습니다.';
  end if;
  if p_housing_type not in ('아파트', '빌라', '원룸', '오피스텔') then
    raise exception '주거 유형을 선택해 주세요.';
  end if;
  if p_building_name is null or char_length(trim(p_building_name)) not between 1 and 200 then
    raise exception '건물 이름을 확인해 주세요.';
  end if;
  if p_rating is null or p_rating not between 1 and 5 then
    raise exception '평점은 1~5점으로 입력해 주세요.';
  end if;
  if p_noise_type not in ('footsteps', 'music', 'construction', 'road', 'other', 'quiet') then
    raise exception '소음 유형을 선택해 주세요.';
  end if;
  if p_content is null or char_length(trim(p_content)) not between 10 and 500 then
    raise exception '후기는 10~500자로 입력해 주세요.';
  end if;

  insert into public.building_reviews
    (building_id, building_name, author_id, housing_type, rating, noise_type, content, status)
  values
    (trim(p_building_id), trim(p_building_name), v_author_id, p_housing_type, p_rating, p_noise_type, trim(p_content), 'pending')
  returning id into v_review_id;

  if v_dong is not null or v_ho is not null then
    insert into public.building_review_units (review_id, author_id, dong, ho)
    values (v_review_id, v_author_id, v_dong, v_ho);
  end if;

  return v_review_id;
end;
$$;

revoke all on function public.submit_building_review(text, text, text, text, text, integer, text, text) from public, anon;
grant execute on function public.submit_building_review(text, text, text, text, text, integer, text, text) to authenticated;
