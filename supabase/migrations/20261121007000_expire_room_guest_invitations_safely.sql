create or replace function public.room_invite_guest(
  p_room_id uuid,
  p_target_zoonl_id text,
  p_seat_number integer,
  p_video_enabled boolean default true,
  p_audio_enabled boolean default true
)
returns uuid
language plpgsql
security definer
set search_path=pg_catalog,public,auth
as $$
declare
  v_user uuid:=auth.uid();
  v_target uuid;
  v_room public.live_rooms%rowtype;
  v_invitation uuid;
begin
  if v_user is null then raise exception 'LOGIN_REQUIRED'; end if;
  if p_seat_number not between 1 and 6 then raise exception 'INVALID_GUEST_SEAT'; end if;
  select * into v_room from public.live_rooms where id=p_room_id for update;
  if not found or not v_room.is_live then raise exception 'ROOM_NOT_LIVE'; end if;
  if v_room.owner_id<>v_user then raise exception 'HOST_ONLY_ACTION'; end if;

  update public.room_guest_invitations
     set invite_status='expired',responded_at=now()
   where room_id=p_room_id and invite_status='pending' and expires_at<=now();

  select user_id into v_target from public.user_public_profiles
   where zoonl_id=trim(coalesce(p_target_zoonl_id,''));
  if v_target is null then raise exception 'ZOONL_ID_NOT_FOUND'; end if;
  if v_target=v_user then raise exception 'HOST_CANNOT_INVITE_SELF'; end if;
  if exists(select 1 from public.room_guest_seats
    where room_id=p_room_id and seat_number=p_seat_number and seat_status<>'available') then
    raise exception 'GUEST_SEAT_NOT_AVAILABLE';
  end if;
  if exists(select 1 from public.room_guest_seats
    where room_id=p_room_id and user_id=v_target and seat_status<>'available') then
    raise exception 'GUEST_ALREADY_IN_ROOM';
  end if;
  insert into public.room_guest_invitations
    (room_id,inviter_id,invitee_id,seat_number,is_video_enabled,is_audio_enabled)
  values
    (p_room_id,v_user,v_target,p_seat_number,coalesce(p_video_enabled,true),coalesce(p_audio_enabled,true))
  returning id into v_invitation;
  return v_invitation;
end;
$$;

create or replace function public.room_respond_guest_invitation(
  p_invitation_id uuid,
  p_accept boolean
)
returns uuid
language plpgsql
security definer
set search_path=pg_catalog,public,auth
as $$
declare
  v_user uuid:=auth.uid();
  v_inv public.room_guest_invitations%rowtype;
  v_room public.live_rooms%rowtype;
  v_seat_id uuid;
begin
  if v_user is null then raise exception 'LOGIN_REQUIRED'; end if;
  select * into v_inv from public.room_guest_invitations
   where id=p_invitation_id and invitee_id=v_user and invite_status='pending'
   for update;
  if not found then raise exception 'GUEST_INVITATION_NOT_AVAILABLE'; end if;
  if v_inv.expires_at<=now() then
    update public.room_guest_invitations set invite_status='expired',responded_at=now() where id=p_invitation_id;
    return null;
  end if;
  select * into v_room from public.live_rooms where id=v_inv.room_id for update;
  if not found or not v_room.is_live then
    update public.room_guest_invitations set invite_status='cancelled',responded_at=now() where id=p_invitation_id;
    return null;
  end if;
  if not p_accept then
    update public.room_guest_invitations set invite_status='rejected',responded_at=now() where id=p_invitation_id;
    return null;
  end if;

  insert into public.room_guest_seats
    (room_id,seat_number,user_id,seat_status,is_video_enabled,is_audio_enabled)
  values
    (v_inv.room_id,v_inv.seat_number,v_user,'occupied',v_inv.is_video_enabled,v_inv.is_audio_enabled)
  on conflict (room_id,seat_number) do update
    set user_id=excluded.user_id,
        seat_status='occupied',
        is_video_enabled=excluded.is_video_enabled,
        is_audio_enabled=excluded.is_audio_enabled
    where public.room_guest_seats.seat_status='available'
  returning id into v_seat_id;
  if v_seat_id is null then raise exception 'GUEST_SEAT_NOT_AVAILABLE'; end if;

  update public.room_guest_invitations set invite_status='accepted',responded_at=now() where id=p_invitation_id;
  return v_seat_id;
end;
$$;

revoke all on function public.room_invite_guest(uuid,text,integer,boolean,boolean) from public,anon;
revoke all on function public.room_respond_guest_invitation(uuid,boolean) from public,anon;
grant execute on function public.room_invite_guest(uuid,text,integer,boolean,boolean) to authenticated;
grant execute on function public.room_respond_guest_invitation(uuid,boolean) to authenticated;
