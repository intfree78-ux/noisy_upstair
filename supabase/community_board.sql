-- 고요 커뮤니티 게시판 설정
-- Supabase 대시보드 > SQL Editor에서 전체 내용을 실행하세요.
create table if not exists public.community_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null default '자유' check (category in ('자유','소음 상담','생활 정보','질문')),
  title text not null check (char_length(title) between 2 and 100),
  content text not null check (char_length(content) between 2 and 5000),
  attachments jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);
create table if not exists public.community_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index if not exists community_posts_created_idx on public.community_posts(created_at desc);
create index if not exists community_posts_category_idx on public.community_posts(category);
create index if not exists community_comments_post_idx on public.community_comments(post_id, created_at);

alter table public.community_posts enable row level security;
alter table public.community_comments enable row level security;
grant select on public.community_posts, public.community_comments to anon, authenticated;
grant insert, delete on public.community_posts, public.community_comments to authenticated;

drop policy if exists "Anyone can read community posts" on public.community_posts;
create policy "Anyone can read community posts" on public.community_posts for select using (true);
drop policy if exists "Members can create own community posts" on public.community_posts;
create policy "Members can create own community posts" on public.community_posts for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Members can delete own community posts" on public.community_posts;
create policy "Members can delete own community posts" on public.community_posts for delete to authenticated using (auth.uid() = user_id);

drop policy if exists "Anyone can read community comments" on public.community_comments;
create policy "Anyone can read community comments" on public.community_comments for select using (true);
drop policy if exists "Members can create own community comments" on public.community_comments;
create policy "Members can create own community comments" on public.community_comments for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Members can delete own community comments" on public.community_comments;
create policy "Members can delete own community comments" on public.community_comments for delete to authenticated using (auth.uid() = user_id);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('community-attachments', 'community-attachments', false, 10485760,
  array['image/jpeg','image/png','image/gif','image/webp','application/pdf','text/plain'])
on conflict (id) do update set public = false, file_size_limit = 10485760,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Members can read community attachments" on storage.objects;
create policy "Members can read community attachments" on storage.objects for select to authenticated
using (bucket_id = 'community-attachments');
drop policy if exists "Members can upload own community attachments" on storage.objects;
create policy "Members can upload own community attachments" on storage.objects for insert to authenticated
with check (bucket_id = 'community-attachments' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "Members can delete own community attachments" on storage.objects;
create policy "Members can delete own community attachments" on storage.objects for delete to authenticated
using (bucket_id = 'community-attachments' and (storage.foldername(name))[1] = auth.uid()::text);
