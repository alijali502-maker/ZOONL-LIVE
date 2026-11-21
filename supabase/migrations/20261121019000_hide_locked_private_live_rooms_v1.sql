
drop policy if exists "Read live rooms" on public.live_rooms;
create policy "Read live rooms"
on public.live_rooms for select to authenticated
using (
  (coalesce(is_private,false)=false and coalesce(is_locked,false)=false)
  or owner_id = (select auth.uid())
  or (select public.is_current_user_live_room_member(live_rooms.id))
);

drop policy if exists "Read room members" on public.live_room_members;
create policy "Read room members"
on public.live_room_members for select to authenticated
using (
  user_id = (select auth.uid())
  or exists (
    select 1 from public.live_rooms r
    where r.id = live_room_members.room_id
      and (
        (coalesce(r.is_private,false)=false and coalesce(r.is_locked,false)=false)
        or r.owner_id = (select auth.uid())
      )
  )
);
