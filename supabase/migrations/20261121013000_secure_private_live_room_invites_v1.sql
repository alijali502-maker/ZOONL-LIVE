create or replace function public.private_room_invite_by_zoonl_id(
  p_room_id uuid,
  p_target_zoonl_id text
) returns jsonb
language plpgsql security definer set search_path = public, auth
as $$
declare
  v_user uuid := auth.uid();
  v_room public.live_rooms%rowtype;
  v_target uuid;
  v_invite public.private_room_invites%rowtype;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if coalesce(trim(p_target_zoonl_id), '') = '' then raise exception 'ZOONL ID is required'; end if;
  select * into v_room from public.live_rooms where id = p_room_id for update;
  if not found or v_room.owner_id <> v_user or v_room.is_live is not true then raise exception 'Only the live room host can invite members'; end if;
  if v_room.is_private is not true and v_room.is_locked is not true then raise exception 'Enable Private or Locked mode before inviting members'; end if;
  select user_id into v_target from public.user_public_profiles where zoonl_id = trim(p_target_zoonl_id) limit 1;
  if v_target is null then raise exception 'ZOONL ID was not found'; end if;
  if v_target = v_user then raise exception 'You cannot invite yourself'; end if;
  if exists(select 1 from public.live_room_members where room_id=p_room_id and user_id=v_target) then
    return jsonb_build_object('success',true,'already_member',true);
  end if;
  select * into v_invite from public.private_room_invites
    where room_id=p_room_id and invitee_id=v_target and invite_status='pending' and expires_at > now()
    order by created_at desc limit 1;
  if not found then
    insert into public.private_room_invites(room_id,inviter_id,invitee_id,invite_status,expires_at)
    values(p_room_id,v_user,v_target,'pending',now()+interval '10 minutes') returning * into v_invite;
  end if;
  return jsonb_build_object('success',true,'invite_id',v_invite.id,'invitee_id',v_target,'expires_at',v_invite.expires_at);
end;
$$;
create or replace function public.private_room_respond_invite(p_invite_id uuid,p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public, auth
as $$
declare
  v_user uuid := auth.uid();
  v_invite public.private_room_invites%rowtype;
  v_room public.live_rooms%rowtype;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select * into v_invite from public.private_room_invites where id=p_invite_id for update;
  if not found or v_invite.invitee_id <> v_user then raise exception 'Invitation not found for this account'; end if;
  if v_invite.invite_status <> 'pending' or v_invite.expires_at <= now() then
    if v_invite.invite_status='pending' then update public.private_room_invites set invite_status='expired' where id=p_invite_id; end if;
    raise exception 'Invitation expired or already answered';
  end if;
  select * into v_room from public.live_rooms where id=v_invite.room_id;
  if not found or v_room.is_live is not true then raise exception 'Live room has ended'; end if;
  update public.private_room_invites set invite_status=case when p_accept then 'accepted' else 'declined' end where id=p_invite_id;
  if p_accept then
    insert into public.live_room_members(room_id,user_id,member_role) values(v_invite.room_id,v_user,'MEMBER')
    on conflict(room_id,user_id) do nothing;
  end if;
  return jsonb_build_object('success',true,'accepted',p_accept,'room_id',v_invite.room_id);
end;
$$;
revoke all on function public.private_room_invite_by_zoonl_id(uuid,text) from public, anon;
revoke all on function public.private_room_respond_invite(uuid,boolean) from public, anon;
grant execute on function public.private_room_invite_by_zoonl_id(uuid,text) to authenticated;
grant execute on function public.private_room_respond_invite(uuid,boolean) to authenticated;
