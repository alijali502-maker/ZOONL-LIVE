create or replace function public.equip_zoonl_cosmetic(p_item_code text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  v_user uuid := auth.uid();
  v_item public.zoonl_live_cosmetics%rowtype;
begin
  if v_user is null then
    raise exception 'LOGIN_REQUIRED';
  end if;

  if nullif(trim(p_item_code), '') is null then
    raise exception 'ITEM_CODE_REQUIRED';
  end if;

  select c.*
    into v_item
  from public.zoonl_live_cosmetics c
  join public.zoonl_live_user_baggage b
    on b.zoonl_item_code = c.zoonl_item_code
   and b.user_id = v_user
   and b.project_name = 'ZOONL LIVE'
   and (b.expires_at is null or b.expires_at > now())
  where c.project_name = 'ZOONL LIVE'
    and c.zoonl_item_code = trim(p_item_code)
    and c.is_active = true
  limit 1;

  if not found then
    raise exception 'ITEM_NOT_OWNED_OR_EXPIRED';
  end if;

  insert into public.zoonl_live_active_styles (user_id, project_name)
  values (v_user, 'ZOONL LIVE')
  on conflict (user_id) do nothing;

  update public.zoonl_live_user_baggage
     set is_equipped = false
   where user_id = v_user
     and project_name = 'ZOONL LIVE'
     and item_type = v_item.item_type;

  update public.zoonl_live_user_baggage
     set is_equipped = true
   where user_id = v_user
     and project_name = 'ZOONL LIVE'
     and zoonl_item_code = v_item.zoonl_item_code
     and (expires_at is null or expires_at > now());

  update public.zoonl_live_active_styles
     set active_profile_bg_code = case when v_item.item_type = 'PROFILE_BG' then v_item.zoonl_item_code else active_profile_bg_code end,
         active_frame_code = case when v_item.item_type = 'AVATAR_FRAME' then v_item.zoonl_item_code else active_frame_code end,
         active_entry_code = case when v_item.item_type = 'ENTRY_EFFECT' then v_item.zoonl_item_code else active_entry_code end,
         active_badge_code = case when v_item.item_type = 'ID_BADGE' then v_item.zoonl_item_code else active_badge_code end,
         active_chat_bubble_code = case when v_item.item_type = 'CHAT_BUBBLE' then v_item.zoonl_item_code else active_chat_bubble_code end,
         updated_at = now()
   where user_id = v_user;

  return jsonb_build_object(
    'success', true,
    'item_code', v_item.zoonl_item_code,
    'item_name', v_item.zoonl_item_name,
    'item_type', v_item.item_type,
    'message', 'ZOONL LIVE cosmetic equipped.'
  );
end;
$function$;

revoke all on function public.equip_zoonl_cosmetic(text) from public;
revoke all on function public.equip_zoonl_cosmetic(text) from anon;
grant execute on function public.equip_zoonl_cosmetic(text) to authenticated;
