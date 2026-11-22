-- Diverse ZOONL LIVE entry cosmetics and server-authoritative room-entry events.
-- The client may request an announcement, but cannot choose another user's effect.

insert into public.zoonl_live_cosmetics
  (project_name, zoonl_item_code, zoonl_item_name, item_type, is_animated_video,
   media_url, sound_fx, color_theme_hex, gradient_cycle_sec, duration_sec,
   min_level_req, coin_price, reward_points, is_active, sort_order)
select 'ZOONL LIVE', v.code, v.name, 'ENTRY_EFFECT', true,
       null, null, v.colors, 5, 4, v.level, v.price, 0, true, v.sort
from (values
  ('ENTRY_HORSE_GOLD','Golden Horse Procession','#F7D98B,#9B6427,#FFF1C2',1,12000,81),
  ('ENTRY_ELEPHANT_ROYAL','Royal Elephant Arrival','#D8C8FF,#7760A8,#FFE8A5',1,18000,82),
  ('ENTRY_LION_ROYAL','Lion King Arrival','#FFC56D,#9D4B20,#FFF0B0',5,22000,83),
  ('ENTRY_BUTTERFLY_GLOW','Butterfly Light Trail','#F4A9E8,#8D70FF,#C6F7FF',1,9000,84),
  ('ENTRY_FALCON_SKY','Falcon Sky Arrival','#A8E9FF,#4A7FB9,#F5FCFF',5,15000,85),
  ('ENTRY_DEER_FOREST','Crystal Deer Arrival','#B8F2D4,#4D977C,#F4FFE8',1,11000,86),
  ('ENTRY_WOLF_SHADOW','Shadow Wolf Arrival','#A8B7D7,#39465F,#E8F0FF',10,19000,87),
  ('ENTRY_DRAGON_EMBER','Ember Dragon Arrival','#FF9A69,#9B2D32,#FFE0A4',15,35000,88),
  ('ENTRY_PHOENIX_FIRE','Phoenix Fire Rise','#FFB46D,#C33E52,#FFF1A8',20,42000,89),
  ('ENTRY_UNICORN_DIAMOND','Diamond Unicorn Arrival','#F3C6FF,#8B78D9,#D4F9FF',10,28000,90),
  ('ENTRY_PEACOCK_ROYAL','Royal Peacock Arrival','#69E7D1,#3169A5,#F5D88D',5,24000,91),
  ('ENTRY_TIGER_EMPEROR','Emperor Tiger Arrival','#FFB66E,#9C4B24,#FFF0C4',15,30000,92)
) as v(code,name,colors,level,price,sort)
where not exists (
  select 1 from public.zoonl_live_cosmetics c
  where c.project_name='ZOONL LIVE' and c.zoonl_item_code=v.code
);

create or replace function public.zoonl_emit_room_entry(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth, private
as $$
declare
  v_user uuid := auth.uid();
  v_room public.live_rooms%rowtype;
  v_entry text;
begin
  if v_user is null then raise exception 'LOGIN_REQUIRED'; end if;
  if p_room_id is null then raise exception 'ROOM_REQUIRED'; end if;

  select * into v_room
  from public.live_rooms
  where id=p_room_id and is_live=true
  for share;

  if not found then raise exception 'ROOM_NOT_LIVE'; end if;

  if v_room.owner_id is distinct from v_user
     and (coalesce(v_room.is_private,false) or coalesce(v_room.is_locked,false))
     and not private.is_current_user_live_room_member(p_room_id) then
    raise exception 'ROOM_ACCESS_DENIED';
  end if;

  select s.active_entry_code into v_entry
  from public.zoonl_live_active_styles s
  join public.zoonl_live_user_baggage b
    on b.user_id=s.user_id
   and b.project_name=s.project_name
   and b.zoonl_item_code=s.active_entry_code
   and b.item_type='ENTRY_EFFECT'
   and (b.expires_at is null or b.expires_at > now())
  join public.zoonl_live_cosmetics c
    on c.project_name=s.project_name
   and c.zoonl_item_code=s.active_entry_code
   and c.item_type='ENTRY_EFFECT'
   and c.is_active=true
  where s.user_id=v_user and s.project_name='ZOONL LIVE'
  limit 1;

  insert into public.live_room_entry_events(room_id,user_id,entry_code)
  values(p_room_id,v_user,v_entry);

  return jsonb_build_object('success',true,'entry_code',v_entry);
end;
$$;

revoke all on function public.zoonl_emit_room_entry(uuid) from public, anon;
grant execute on function public.zoonl_emit_room_entry(uuid) to authenticated;
