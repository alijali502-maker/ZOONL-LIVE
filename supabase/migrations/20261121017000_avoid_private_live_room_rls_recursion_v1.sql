
create or replace function public.is_current_user_live_room_member(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1 from public.live_room_members m
    where m.room_id = p_room_id and m.user_id = auth.uid()
  );
$$;

revoke all on function public.is_current_user_live_room_member(uuid) from public, anon;
grant execute on function public.is_current_user_live_room_member(uuid) to authenticated;

drop policy if exists "Read live rooms" on public.live_rooms;
create policy "Read live rooms"
on public.live_rooms
for select
to authenticated
using (
  is_private = false
  or owner_id = (select auth.uid())
  or (select public.is_current_user_live_room_member(live_rooms.id))
);
