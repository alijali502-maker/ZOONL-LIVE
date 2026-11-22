-- ZOONL LIVE Prime chat identities, cosmetic media storage, and live chat moderation.
-- Prime IV is SVIP; Prime V is VVIP. Existing wallet prices and purchases remain unchanged.

update public.prime_tiers
set benefits = coalesce(benefits, '{}'::jsonb) || case id
  when 1 then jsonb_build_object('chat_tier','VIP','chat_color','#FFE7A6,#B77A22,#57320D')
  when 2 then jsonb_build_object('chat_tier','VIP','chat_color','#FFE7A6,#B77A22,#57320D')
  when 3 then jsonb_build_object('chat_tier','VIP','chat_color','#FFE7A6,#B77A22,#57320D')
  when 4 then jsonb_build_object('chat_tier','SVIP','chat_color','#FF9AA8,#E3264F,#650F2B')
  when 5 then jsonb_build_object('chat_tier','VVIP','chat_color','#D9B6FF,#8B4DDB,#241044')
  else '{}'::jsonb end;

create or replace function public.get_public_chat_styles(p_user_ids uuid[])
returns table(user_id uuid, tier_code text, tier_label text, chat_color_hex text)
language sql stable security definer
set search_path = pg_catalog, public, auth
as $$
  select requested.user_id,
    case
      when exists (select 1 from public.zoonl_user_trials t
        where t.user_id=requested.user_id and t.trial_status='active'
          and t.svip_active=true and t.expires_at>now()) then 'SVIP'
      when membership.prime_tier_id=5 then 'VVIP'
      when membership.prime_tier_id=4 then 'SVIP'
      when membership.prime_tier_id between 1 and 3 then 'VIP'
      else 'NONE'
    end,
    case
      when exists (select 1 from public.zoonl_user_trials t
        where t.user_id=requested.user_id and t.trial_status='active'
          and t.svip_active=true and t.expires_at>now()) then 'SVIP'
      when membership.prime_tier_id=5 then 'VVIP'
      when membership.prime_tier_id=4 then 'SVIP'
      when membership.prime_tier_id between 1 and 3 then 'VIP'
      else ''
    end,
    coalesce(nullif(chat_cosmetic.color_theme_hex,''),
      case
        when exists (select 1 from public.zoonl_user_trials t
          where t.user_id=requested.user_id and t.trial_status='active'
            and t.svip_active=true and t.expires_at>now())
          or membership.prime_tier_id=4 then '#FF9AA8,#E3264F,#650F2B'
        when membership.prime_tier_id=5 then '#D9B6FF,#8B4DDB,#241044'
        when membership.prime_tier_id between 1 and 3 then '#FFE7A6,#B77A22,#57320D'
        else '#E4D0AA,#98734A,#45301F'
      end)
  from (select distinct unnest(coalesce(p_user_ids,'{}'::uuid[])) as user_id) requested
  left join lateral (
    select m.prime_tier_id from public.user_prime_memberships m
    where m.user_id=requested.user_id and m.is_active=true
      and (m.expires_at is null or m.expires_at>now())
    order by m.prime_tier_id desc limit 1
  ) membership on true
  left join public.zoonl_live_active_styles active_style
    on active_style.user_id=requested.user_id and active_style.project_name='ZOONL LIVE'
  left join public.zoonl_live_user_baggage baggage
    on baggage.user_id=requested.user_id and baggage.project_name='ZOONL LIVE'
   and baggage.zoonl_item_code=active_style.active_chat_bubble_code
   and baggage.item_type='CHAT_BUBBLE' and baggage.is_equipped=true
   and (baggage.expires_at is null or baggage.expires_at>now())
  left join public.zoonl_live_cosmetics chat_cosmetic
    on chat_cosmetic.project_name='ZOONL LIVE'
   and chat_cosmetic.zoonl_item_code=active_style.active_chat_bubble_code
   and chat_cosmetic.item_type='CHAT_BUBBLE' and chat_cosmetic.is_active=true
  where auth.uid() is not null;
$$;
revoke all on function public.get_public_chat_styles(uuid[]) from public, anon;
grant execute on function public.get_public_chat_styles(uuid[]) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('zoonl-live-cosmetics','zoonl-live-cosmetics',true,52428800,
  array['image/png','image/jpeg','image/webp','image/gif','video/mp4','video/webm'])
on conflict (id) do update set public=true,file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "ZOONL cosmetics media public read" on storage.objects;
create policy "ZOONL cosmetics media public read" on storage.objects
for select to anon, authenticated using (bucket_id='zoonl-live-cosmetics');
drop policy if exists "ZOONL owner uploads cosmetics media" on storage.objects;
create policy "ZOONL owner uploads cosmetics media" on storage.objects
for insert to authenticated with check (bucket_id='zoonl-live-cosmetics' and public.is_zoonl_owner());
drop policy if exists "ZOONL owner updates cosmetics media" on storage.objects;
create policy "ZOONL owner updates cosmetics media" on storage.objects
for update to authenticated using (bucket_id='zoonl-live-cosmetics' and public.is_zoonl_owner())
with check (bucket_id='zoonl-live-cosmetics' and public.is_zoonl_owner());
drop policy if exists "ZOONL owner deletes cosmetics media" on storage.objects;
create policy "ZOONL owner deletes cosmetics media" on storage.objects
for delete to authenticated using (bucket_id='zoonl-live-cosmetics' and public.is_zoonl_owner());

create table if not exists public.live_room_chat_mutes (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.live_rooms(id) on delete cascade,
  muted_user_id uuid not null references auth.users(id) on delete cascade,
  muted_by uuid not null references auth.users(id) on delete cascade,
  reason text not null default '',
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  constraint live_room_chat_mutes_valid_expiry check (expires_at is null or expires_at>created_at),
  unique(room_id,muted_user_id)
);
create index if not exists live_room_chat_mutes_active_idx
on public.live_room_chat_mutes(room_id,muted_user_id,expires_at);
alter table public.live_room_chat_mutes enable row level security;
revoke all on public.live_room_chat_mutes from anon, authenticated;

create or replace function public.moderate_live_chat_user(
  p_room_id uuid,p_target_user_id uuid,p_muted boolean default true,
  p_reason text default '',p_duration_minutes integer default null
) returns jsonb language plpgsql security definer
set search_path = pg_catalog, public, auth, private
as $$
declare v_actor uuid:=auth.uid(); v_room public.live_rooms%rowtype;
begin
  if v_actor is null then raise exception 'LOGIN_REQUIRED'; end if;
  if p_room_id is null or p_target_user_id is null then raise exception 'ROOM_AND_TARGET_REQUIRED'; end if;
  if p_target_user_id=v_actor then raise exception 'CANNOT_MODERATE_SELF'; end if;
  if p_duration_minutes is not null and (p_duration_minutes<1 or p_duration_minutes>10080) then
    raise exception 'INVALID_MUTE_DURATION';
  end if;
  select * into v_room from public.live_rooms where id=p_room_id and is_live=true for share;
  if not found then raise exception 'ROOM_NOT_LIVE'; end if;
  if v_room.owner_id is distinct from v_actor and not public.is_zoonl_owner()
     and not public.is_zoonl_admin_allowed('moderate_live_chat') then
    raise exception 'MODERATE_LIVE_CHAT_PERMISSION_REQUIRED';
  end if;
  if not exists(select 1 from public.live_room_members m
    where m.room_id=p_room_id and m.user_id=p_target_user_id)
    and v_room.owner_id is distinct from p_target_user_id then
    raise exception 'TARGET_NOT_IN_ROOM';
  end if;
  if p_muted then
    insert into public.live_room_chat_mutes(room_id,muted_user_id,muted_by,reason,expires_at)
    values(p_room_id,p_target_user_id,v_actor,left(coalesce(p_reason,''),240),
      case when p_duration_minutes is null then null else now()+make_interval(mins=>p_duration_minutes) end)
    on conflict(room_id,muted_user_id) do update set muted_by=excluded.muted_by,
      reason=excluded.reason,created_at=now(),expires_at=excluded.expires_at;
  else
    delete from public.live_room_chat_mutes where room_id=p_room_id and muted_user_id=p_target_user_id;
  end if;
  return jsonb_build_object('success',true,'muted',p_muted,'target_user_id',p_target_user_id);
end;
$$;
revoke all on function public.moderate_live_chat_user(uuid,uuid,boolean,text,integer) from public,anon;
grant execute on function public.moderate_live_chat_user(uuid,uuid,boolean,text,integer) to authenticated;

drop policy if exists "Authenticated users can read room chat" on public.chat_messages;
create policy "Authenticated users can read room chat" on public.chat_messages
for select to authenticated using (
  not exists(select 1 from public.live_room_chat_mutes mute
    where mute.room_id=chat_messages.room_id and mute.muted_user_id=chat_messages.sender_id
      and (mute.expires_at is null or mute.expires_at>now()))
);
