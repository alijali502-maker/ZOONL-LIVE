create table if not exists public.short_videos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null unique,
  video_url text not null,
  caption text not null default '',
  filter_name text not null default 'Natural',
  duration_seconds integer not null check (duration_seconds between 1 and 60),
  is_public boolean not null default true,
  likes_count bigint not null default 0 check (likes_count >= 0),
  created_at timestamptz not null default now()
);
create index if not exists short_videos_public_created_idx
  on public.short_videos(created_at desc) where is_public=true;
create index if not exists short_videos_user_created_idx
  on public.short_videos(user_id,created_at desc);

create table if not exists public.short_video_likes (
  video_id uuid not null references public.short_videos(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(video_id,user_id)
);

alter table public.short_videos enable row level security;
alter table public.short_video_likes enable row level security;

drop policy if exists short_videos_read_public_or_own on public.short_videos;
create policy short_videos_read_public_or_own on public.short_videos
for select to authenticated
using (is_public=true or user_id=(select auth.uid()));
drop policy if exists short_videos_insert_own on public.short_videos;
create policy short_videos_insert_own on public.short_videos
for insert to authenticated
with check (
  user_id=(select auth.uid())
  and storage_path like (auth.uid()::text || '/%')
  and is_public=true
);
drop policy if exists short_videos_update_own on public.short_videos;
create policy short_videos_update_own on public.short_videos
for update to authenticated
using (user_id=(select auth.uid()))
with check (user_id=(select auth.uid()));
drop policy if exists short_videos_delete_own on public.short_videos;
create policy short_videos_delete_own on public.short_videos
for delete to authenticated
using (user_id=(select auth.uid()));

drop policy if exists short_video_likes_read_authenticated on public.short_video_likes;
create policy short_video_likes_read_authenticated on public.short_video_likes
for select to authenticated using (true);

revoke insert, update, delete on public.short_video_likes from anon, authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values(
  'zoonl-shorts','zoonl-shorts',true,104857600,
  array['video/mp4','video/quicktime','video/webm']
)
on conflict(id) do update set
  public=true,
  file_size_limit=104857600,
  allowed_mime_types=array['video/mp4','video/quicktime','video/webm'];

drop policy if exists zoonl_shorts_public_read on storage.objects;
create policy zoonl_shorts_public_read on storage.objects
for select to public
using (bucket_id='zoonl-shorts');

drop policy if exists zoonl_shorts_upload_own on storage.objects;
create policy zoonl_shorts_upload_own on storage.objects
for insert to authenticated
with check (
  bucket_id='zoonl-shorts'
  and (storage.foldername(name))[1]=(select auth.uid())::text
);

drop policy if exists zoonl_shorts_update_own on storage.objects;
create policy zoonl_shorts_update_own on storage.objects
for update to authenticated
using (
  bucket_id='zoonl-shorts'
  and (storage.foldername(name))[1]=(select auth.uid())::text
)
with check (
  bucket_id='zoonl-shorts'
  and (storage.foldername(name))[1]=(select auth.uid())::text
);

drop policy if exists zoonl_shorts_delete_own on storage.objects;
create policy zoonl_shorts_delete_own on storage.objects
for delete to authenticated
using (
  bucket_id='zoonl-shorts'
  and (storage.foldername(name))[1]=(select auth.uid())::text
);

create or replace function public.toggle_short_video_like(p_video_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=pg_catalog,public,auth
as $$
declare
  v_user uuid:=auth.uid();
  v_liked boolean;
  v_count bigint;
begin
  if v_user is null then raise exception 'LOGIN_REQUIRED'; end if;
  if not exists(select 1 from public.short_videos where id=p_video_id and (is_public=true or user_id=v_user)) then
    raise exception 'VIDEO_NOT_AVAILABLE';
  end if;
  if exists(select 1 from public.short_video_likes where video_id=p_video_id and user_id=v_user) then
    delete from public.short_video_likes where video_id=p_video_id and user_id=v_user;
    v_liked:=false;
  else
    insert into public.short_video_likes(video_id,user_id) values(p_video_id,v_user)
    on conflict(video_id,user_id) do nothing;
    v_liked:=true;
  end if;
  select count(*) into v_count from public.short_video_likes where video_id=p_video_id;
  update public.short_videos set likes_count=v_count where id=p_video_id;
  return jsonb_build_object('liked',v_liked,'likes_count',v_count);
end;
$$;
revoke all on function public.toggle_short_video_like(uuid) from public,anon;
grant execute on function public.toggle_short_video_like(uuid) to authenticated;
