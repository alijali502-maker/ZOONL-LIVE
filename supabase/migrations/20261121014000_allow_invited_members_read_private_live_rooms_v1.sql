drop policy if exists "Read live rooms" on public.live_rooms;
create policy "Read live rooms" on public.live_rooms for select to authenticated
using (is_private = false or owner_id = (select auth.uid()) or exists (
  select 1 from public.live_room_members m
  where m.room_id = live_rooms.id and m.user_id = (select auth.uid())
));