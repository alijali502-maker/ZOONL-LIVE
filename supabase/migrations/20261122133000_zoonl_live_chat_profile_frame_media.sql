drop function if exists public.get_public_chat_styles(uuid[]);
create function public.get_public_chat_styles(p_user_ids uuid[])
returns table(user_id uuid,tier_code text,tier_label text,chat_color_hex text,frame_media_url text,frame_color_hex text)
language sql stable security definer
set search_path = pg_catalog, public, auth
as $$
  select requested.user_id,
    case
      when exists (select 1 from public.zoonl_user_trials t where t.user_id=requested.user_id
        and t.trial_status='active' and t.svip_active=true and t.expires_at>now()) then 'SVIP'
      when membership.prime_tier_id=5 then 'VVIP'
      when membership.prime_tier_id=4 then 'SVIP'
      when membership.prime_tier_id between 1 and 3 then 'VIP'
      else 'NONE'
    end,
    case
      when exists (select 1 from public.zoonl_user_trials t where t.user_id=requested.user_id
        and t.trial_status='active' and t.svip_active=true and t.expires_at>now()) then 'SVIP'
      when membership.prime_tier_id=5 then 'VVIP'
      when membership.prime_tier_id=4 then 'SVIP'
      when membership.prime_tier_id between 1 and 3 then 'VIP'
      else ''
    end,
    coalesce(nullif(chat_cosmetic.color_theme_hex,''),
      case
        when exists (select 1 from public.zoonl_user_trials t where t.user_id=requested.user_id
          and t.trial_status='active' and t.svip_active=true and t.expires_at>now())
          or membership.prime_tier_id=4 then '#FF9AA8,#E3264F,#650F2B'
        when membership.prime_tier_id=5 then '#D9B6FF,#8B4DDB,#241044'
        when membership.prime_tier_id between 1 and 3 then '#FFE7A6,#B77A22,#57320D'
        else '#E4D0AA,#98734A,#45301F'
      end),
    frame_cosmetic.media_url,
    frame_cosmetic.color_theme_hex
  from (select distinct unnest(coalesce(p_user_ids,'{}'::uuid[])) as user_id) requested
  left join lateral (
    select m.prime_tier_id from public.user_prime_memberships m
    where m.user_id=requested.user_id and m.is_active=true
      and (m.expires_at is null or m.expires_at>now())
    order by m.prime_tier_id desc limit 1
  ) membership on true
  left join public.zoonl_live_active_styles active_style
    on active_style.user_id=requested.user_id and active_style.project_name='ZOONL LIVE'
  left join public.zoonl_live_user_baggage chat_baggage
    on chat_baggage.user_id=requested.user_id and chat_baggage.project_name='ZOONL LIVE'
   and chat_baggage.zoonl_item_code=active_style.active_chat_bubble_code
   and chat_baggage.item_type='CHAT_BUBBLE' and chat_baggage.is_equipped=true
   and (chat_baggage.expires_at is null or chat_baggage.expires_at>now())
  left join public.zoonl_live_cosmetics chat_cosmetic
    on chat_cosmetic.project_name='ZOONL LIVE'
   and chat_cosmetic.zoonl_item_code=active_style.active_chat_bubble_code
   and chat_cosmetic.item_type='CHAT_BUBBLE' and chat_cosmetic.is_active=true
  left join public.zoonl_live_user_baggage frame_baggage
    on frame_baggage.user_id=requested.user_id and frame_baggage.project_name='ZOONL LIVE'
   and frame_baggage.zoonl_item_code=active_style.active_frame_code
   and frame_baggage.item_type='AVATAR_FRAME' and frame_baggage.is_equipped=true
   and (frame_baggage.expires_at is null or frame_baggage.expires_at>now())
  left join public.zoonl_live_cosmetics frame_cosmetic
    on frame_cosmetic.project_name='ZOONL LIVE'
   and frame_cosmetic.zoonl_item_code=active_style.active_frame_code
   and frame_cosmetic.item_type='AVATAR_FRAME' and frame_cosmetic.is_active=true
  where auth.uid() is not null;
$$;
revoke all on function public.get_public_chat_styles(uuid[]) from public,anon;
grant execute on function public.get_public_chat_styles(uuid[]) to authenticated;
