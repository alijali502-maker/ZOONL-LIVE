
drop policy if exists "Users update own public profile media" on public.user_public_profiles;
create policy "Users update own public profile media"
on public.user_public_profiles for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));
revoke update on public.user_public_profiles from authenticated;
grant update (avatar_url, bio, updated_at) on public.user_public_profiles to authenticated;
