create table if not exists public.room_guest_invitations (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.live_rooms(id) on delete cascade,
  inviter_id uuid not null references auth.users(id) on delete cascade,
  invitee_id uuid not null references auth.users(id) on delete cascade,
  seat_number integer not null check (seat_number between 1 and 6),
  invite_status text not null default 'pending'
    check (invite_status in ('pending','accepted','rejected','cancelled','expired')),
  is_video_enabled boolean not null default true,
  is_audio_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '10 minutes',
  responded_at timestamptz
);

create unique index if not exists room_guest_invites_pending_seat_idx
  on public.room_guest_invitations(room_id, seat_number)
  where invite_status='pending';
create unique index if not exists room_guest_invites_pending_user_idx
  on public.room_guest_invitations(room_id, invitee_id)
  where invite_status='pending';

alter table public.room_guest_invitations enable row level security;
drop policy if exists room_guest_invites_read_own on public.room_guest_invitations;
create policy room_guest_invites_read_own on public.room_guest_invitations
for select to authenticated
using (inviter_id=(select auth.uid()) or invitee_id=(select auth.uid()));
revoke insert, update, delete, truncate, references, trigger
on public.room_guest_invitations from anon, authenticated;

drop policy if exists room_guest_seats_read_owner_or_guest on public.room_guest_seats;
create policy room_guest_seats_read_owner_or_guest on public.room_guest_seats
for select to authenticated
using (
  user_id=(select auth.uid())
  or exists (
    select 1 from public.live_rooms r
    where r.id=room_guest_seats.room_id and r.owner_id=(select auth.uid())
  )
  or exists (
    select 1 from public.live_rooms r
    where r.id=room_guest_seats.room_id and r.is_private=false
  )
);

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
    raise exception 'GUEST_INVITATION_EXPIRED';
  end if;
  select * into v_room from public.live_rooms where id=v_inv.room_id for update;
  if not found or not v_room.is_live then raise exception 'ROOM_NOT_LIVE'; end if;

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

create or replace function public.room_remove_guest(p_seat_id uuid)
returns boolean
language plpgsql
security definer
set search_path=pg_catalog,public,auth
as $$
declare
  v_user uuid:=auth.uid();
begin
  if v_user is null then raise exception 'LOGIN_REQUIRED'; end if;
  update public.room_guest_seats s
     set user_id=null,seat_status='available',is_video_enabled=true,is_audio_enabled=true
    from public.live_rooms r
   where s.id=p_seat_id and r.id=s.room_id and r.owner_id=v_user;
  if not found then raise exception 'HOST_ONLY_OR_SEAT_NOT_FOUND'; end if;
  return true;
end;
$$;

revoke all on function public.room_invite_guest(uuid,text,integer,boolean,boolean) from public,anon;
revoke all on function public.room_respond_guest_invitation(uuid,boolean) from public,anon;
revoke all on function public.room_remove_guest(uuid) from public,anon;
grant execute on function public.room_invite_guest(uuid,text,integer,boolean,boolean) to authenticated;
grant execute on function public.room_respond_guest_invitation(uuid,boolean) to authenticated;
grant execute on function public.room_remove_guest(uuid) to authenticated;

do $$
begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='room_guest_invitations') then
   alter publication supabase_realtime add table public.room_guest_invitations;
  end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='room_guest_seats') then
   alter publication supabase_realtime add table public.room_guest_seats;
  end if;
 end if;
end;
$$;
