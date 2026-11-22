create or replace function private.release_room_guest_seats_on_end()
returns trigger
language plpgsql
security definer
set search_path=pg_catalog,public,auth
as $$
begin
  if old.is_live=true and new.is_live=false then
    update public.room_guest_seats
       set user_id=null,seat_status='available',
           is_video_enabled=true,is_audio_enabled=true
     where room_id=new.id;
    update public.room_guest_invitations
       set invite_status='cancelled',responded_at=now()
     where room_id=new.id and invite_status='pending';
  end if;
  return new;
end;
$$;

drop trigger if exists release_room_guest_seats_after_live_end on public.live_rooms;
create trigger release_room_guest_seats_after_live_end
after update of is_live on public.live_rooms
for each row
execute function private.release_room_guest_seats_on_end();
