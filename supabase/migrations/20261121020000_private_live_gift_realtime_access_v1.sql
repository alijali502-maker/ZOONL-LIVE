
drop policy if exists gift_sends_read_room on public.gift_sends;
create policy gift_sends_read_room
on public.gift_sends for select to authenticated
using (
  exists (
    select 1 from public.live_rooms r
    where r.id = gift_sends.room_id
      and r.is_live = true
      and (
        (coalesce(r.is_private,false)=false and coalesce(r.is_locked,false)=false)
        or r.owner_id = (select auth.uid())
        or (select public.is_current_user_live_room_member(r.id))
      )
  )
);
