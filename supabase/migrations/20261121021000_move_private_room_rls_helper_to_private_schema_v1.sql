
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.is_current_user_live_room_member(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select
    exists (
      select 1 from public.live_room_members m
      where m.room_id = p_room_id and m.user_id = auth.uid()
    )
    or exists (
      select 1 from public.room_guest_seats s
      where s.room_id = p_room_id
        and s.user_id = auth.uid()
        and s.seat_status = 'occupied'
    );
$$;

revoke all on function private.is_current_user_live_room_member(uuid) from public, anon;
grant execute on function private.is_current_user_live_room_member(uuid) to authenticated;
revoke all on function public.is_current_user_live_room_member(uuid) from public, anon, authenticated;

drop policy if exists "Read live rooms" on public.live_rooms;
create policy "Read live rooms"
on public.live_rooms for select to authenticated
using (
  (coalesce(is_private,false)=false and coalesce(is_locked,false)=false)
  or owner_id = (select auth.uid())
  or (select private.is_current_user_live_room_member(live_rooms.id))
);

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
        or (select private.is_current_user_live_room_member(r.id))
      )
  )
);
