-- Verified Owner account progression and permanent Owner cosmetics/Prime.
-- Owner identity is sourced only from owner_control_settings, never from public ZOONL ID.

create or replace function public.zoonl_my_level()
returns integer
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
  select case
    when public.is_zoonl_owner() then 100
    else greatest(
      coalesce((select p.user_level from public.profiles p where p.id = auth.uid()), 1),
      coalesce((
        select max(d.level)
        from public.level_definitions d
        where d.required_exp <= coalesce((
          select sum(g.total_coins) from public.gift_sends g where g.sender_id = auth.uid()
        ), 0)
      ), 1)
    )::int
  end;
$function$;

-- This migration runs with database-owner privileges. The target is the
-- canonical owner_user_id row, not a user-supplied account identifier.
update public.profiles p
set user_level = 100, updated_at = now()
where p.id = (select s.owner_user_id from public.owner_control_settings s where s.id = 1);

update public.user_prime_memberships m
set is_active = false
where m.user_id = (select s.owner_user_id from public.owner_control_settings s where s.id = 1)
  and m.is_active = true;

insert into public.user_prime_memberships
  (user_id, prime_tier_id, started_at, expires_at, is_active)
select s.owner_user_id, 5, now(), null, true
from public.owner_control_settings s
where s.id = 1
  and exists (select 1 from public.prime_tiers t where t.id = 5 and t.is_active = true)
  and not exists (
    select 1 from public.user_prime_memberships m
    where m.user_id = s.owner_user_id and m.prime_tier_id = 5
      and m.is_active = true and m.expires_at is null
  );

insert into public.zoonl_live_cosmetics
  (project_name, zoonl_item_code, zoonl_item_name, item_type, is_animated_video,
   media_url, sound_fx, color_theme_hex, gradient_cycle_sec, duration_sec,
   min_level_req, coin_price, reward_points, is_active, sort_order)
select 'ZOONL LIVE', 'ZOONL_OWNER_BADGE', 'ZOONL Sovereign Owner Glass Badge',
       'ID_BADGE', false, '', '', '#F7E5A8,#D7B76D,#FFF5D6',
       0, 0, 1, 0, 0, true, 1
where not exists (
  select 1 from public.zoonl_live_cosmetics
  where project_name = 'ZOONL LIVE' and zoonl_item_code = 'ZOONL_OWNER_BADGE'
);

insert into public.zoonl_live_user_baggage
  (project_name, user_id, zoonl_item_code, item_type, is_equipped, acquired_via, expires_at)
select 'ZOONL LIVE', s.owner_user_id, 'ZOONL_OWNER_BADGE', 'ID_BADGE', true, 'OWNER_GRANT', null
from public.owner_control_settings s
where s.id = 1
  and not exists (
    select 1 from public.zoonl_live_user_baggage b
    where b.user_id = s.owner_user_id and b.project_name = 'ZOONL LIVE'
      and b.zoonl_item_code = 'ZOONL_OWNER_BADGE'
      and (b.expires_at is null or b.expires_at > now())
  );

insert into public.zoonl_live_active_styles (user_id, project_name, active_badge_code)
select s.owner_user_id, 'ZOONL LIVE', 'ZOONL_OWNER_BADGE'
from public.owner_control_settings s where s.id = 1
on conflict (user_id) do update
set active_badge_code = excluded.active_badge_code, updated_at = now();
