create or replace function public.room_leave_guest_seat(p_seat_id uuid)
returns boolean
language plpgsql
security definer
set search_path=pg_catalog,public,auth
as $$
begin
  if auth.uid() is null then raise exception 'LOGIN_REQUIRED'; end if;
  update public.room_guest_seats
     set user_id=null,seat_status='available',is_video_enabled=true,is_audio_enabled=true
   where id=p_seat_id and user_id=auth.uid();
  if not found then raise exception 'GUEST_SEAT_NOT_FOUND'; end if;
  return true;
end;
$$;
revoke all on function public.room_leave_guest_seat(uuid) from public,anon;
grant execute on function public.room_leave_guest_seat(uuid) to authenticated;
