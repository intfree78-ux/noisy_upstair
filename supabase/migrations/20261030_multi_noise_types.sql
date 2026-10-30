-- Add multi-select noise types to building reviews.
alter table public.building_reviews
  add column if not exists noise_types text[] not null default '{}';

alter table public.building_reviews
  drop constraint if exists building_reviews_noise_types_check;

alter table public.building_reviews
  add constraint building_reviews_noise_types_check
  check (noise_types <@ array['footsteps','music','construction','road','other','quiet']::text[]);

grant select (noise_types) on public.building_reviews to anon, authenticated;

create or replace function public.submit_building_review(
  p_building_id text,
  p_building_name text,
  p_housing_type text,
  p_dong text,
  p_ho text,
  p_rating integer,
  p_noise_types text[],
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
  v_noise_types text[] := coalesce(p_noise_types, '{}'::text[]);
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
  if cardinality(v_noise_types) < 1 or cardinality(v_noise_types) > 6
     or not (v_noise_types <@ array['footsteps','music','construction','road','other','quiet']::text[]) then
    raise exception '소음 유형을 하나 이상 선택해 주세요.';
  end if;
  if p_content is null or char_length(trim(p_content)) not between 10 and 500 then
    raise exception '후기는 10~500자로 입력해 주세요.';
  end if;

  insert into public.building_reviews
    (building_id, building_name, author_id, housing_type, rating, noise_type, noise_types, content, status)
  values
    (trim(p_building_id), trim(p_building_name), v_author_id, p_housing_type, p_rating, v_noise_types[1], v_noise_types, trim(p_content), 'pending')
  returning id into v_review_id;

  if v_dong is not null or v_ho is not null then
    insert into public.building_review_units (review_id, author_id, dong, ho)
    values (v_review_id, v_author_id, v_dong, v_ho);
  end if;

  return v_review_id;
end;
$$;

revoke all on function public.submit_building_review(text, text, text, text, text, integer, text[], text) from public, anon;
grant execute on function public.submit_building_review(text, text, text, text, text, integer, text[], text) to authenticated;
