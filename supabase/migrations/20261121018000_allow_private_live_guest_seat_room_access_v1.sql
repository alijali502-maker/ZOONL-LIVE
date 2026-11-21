
create or replace function public.is_current_user_live_room_member(p_room_id uuid)
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

revoke all on function public.is_current_user_live_room_member(uuid) from public, anon;
grant execute on function public.is_current_user_live_room_member(uuid) to authenticated;
