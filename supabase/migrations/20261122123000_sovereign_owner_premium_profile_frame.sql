-- Exclusive Sovereign Owner frame: granted only to the trusted owner account.
insert into public.zoonl_live_cosmetics
  (project_name, zoonl_item_code, zoonl_item_name, item_type, is_animated_video,
   media_url, sound_fx, color_theme_hex, gradient_cycle_sec, duration_sec,
   min_level_req, coin_price, reward_points, is_active, sort_order)
select 'ZOONL LIVE','ZOONL_SOVEREIGN_OWNER_FRAME','Sovereign Crown ID Frame',
       'AVATAR_FRAME',false,'','',
       '#FFF7D2,#E6BE63,#FFFDF1,#8C5B19,#F8E5A6',3,0,100,0,0,true,0
where not exists (
  select 1 from public.zoonl_live_cosmetics
  where project_name='ZOONL LIVE' and zoonl_item_code='ZOONL_SOVEREIGN_OWNER_FRAME'
);

insert into public.zoonl_live_user_baggage
  (project_name,user_id,zoonl_item_code,item_type,is_equipped,acquired_via,expires_at)
select 'ZOONL LIVE',s.owner_user_id,'ZOONL_SOVEREIGN_OWNER_FRAME',
       'AVATAR_FRAME',true,'OWNER_GRANT',null
from public.owner_control_settings s
where s.id=1 and s.owner_user_id is not null
  and not exists (
    select 1 from public.zoonl_live_user_baggage b
    where b.project_name='ZOONL LIVE' and b.user_id=s.owner_user_id
      and b.zoonl_item_code='ZOONL_SOVEREIGN_OWNER_FRAME'
      and (b.expires_at is null or b.expires_at>now())
  );

insert into public.zoonl_live_active_styles
  (user_id,project_name,active_frame_code)
select s.owner_user_id,'ZOONL LIVE','ZOONL_SOVEREIGN_OWNER_FRAME'
from public.owner_control_settings s
where s.id=1 and s.owner_user_id is not null
on conflict (user_id) do update
set active_frame_code=excluded.active_frame_code,updated_at=now();
