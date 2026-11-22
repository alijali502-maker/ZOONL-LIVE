create or replace function public.owner_set_live_chat_moderator(
  p_target_zoonl_id text,
  p_is_allowed boolean
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, public, auth
as $$
declare v_target uuid;
begin
  if auth.uid() is null then raise exception 'LOGIN_REQUIRED'; end if;
  if not public.is_zoonl_owner() then raise exception 'OWNER_ONLY'; end if;
  if nullif(trim(p_target_zoonl_id),'') is null then raise exception 'ZOONL_ID_REQUIRED'; end if;
  select user_id into v_target from public.user_public_profiles
  where zoonl_id=trim(p_target_zoonl_id) limit 1;
  if v_target is null then raise exception 'USER_ID_NOT_FOUND'; end if;
  if v_target=auth.uid() then raise exception 'OWNER_ALREADY_HAS_ACCESS'; end if;
  insert into public.owner_admin_permissions(admin_user_id,permission_key,is_allowed,granted_by)
  values(v_target,'moderate_live_chat',p_is_allowed,auth.uid())
  on conflict(admin_user_id,permission_key) do update
  set is_allowed=excluded.is_allowed,granted_by=excluded.granted_by,created_at=now();
  return jsonb_build_object('success',true,'zoonl_id',trim(p_target_zoonl_id),
    'permission_key','moderate_live_chat','is_allowed',p_is_allowed);
end;
$$;
revoke all on function public.owner_set_live_chat_moderator(text,boolean) from public,anon;
grant execute on function public.owner_set_live_chat_moderator(text,boolean) to authenticated;
