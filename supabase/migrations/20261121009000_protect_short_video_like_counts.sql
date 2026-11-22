drop policy if exists short_videos_insert_own on public.short_videos;
create policy short_videos_insert_own on public.short_videos
for insert to authenticated
with check (
  user_id=(select auth.uid())
  and storage_path like ((select auth.uid())::text || '/%')
  and is_public=true
  and likes_count=0
);
revoke update on public.short_videos from anon,authenticated;
