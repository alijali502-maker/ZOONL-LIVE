revoke all on function public.is_zoonl_owner() from public, anon;
grant execute on function public.is_zoonl_owner() to authenticated;

revoke all on function public.is_zoonl_admin_allowed(text) from public, anon;
grant execute on function public.is_zoonl_admin_allowed(text) to authenticated;

revoke all on function public.is_zoonl_agency_admin_allowed(bigint, text) from public, anon;
grant execute on function public.is_zoonl_agency_admin_allowed(bigint, text) to authenticated;

revoke all on function public.can_message_user(uuid) from public, anon;
grant execute on function public.can_message_user(uuid) to authenticated;

revoke all on function public.add_zoonl_coins(text, bigint, text) from public, anon;
grant execute on function public.add_zoonl_coins(text, bigint, text) to authenticated;

revoke all on function public.owner_create_agency(text, text, numeric) from public, anon;
grant execute on function public.owner_create_agency(text, text, numeric) to authenticated;

revoke all on function public.owner_list_agencies() from public, anon;
grant execute on function public.owner_list_agencies() to authenticated;

revoke all on function public.owner_set_admin_topup_permission(text, boolean) from public, anon;
grant execute on function public.owner_set_admin_topup_permission(text, boolean) to authenticated;

revoke all on function public.owner_set_agency_status(uuid, text) from public, anon;
grant execute on function public.owner_set_agency_status(uuid, text) to authenticated;

revoke all on function public.send_live_gift(uuid, uuid, integer) from public, anon;
grant execute on function public.send_live_gift(uuid, uuid, integer) to authenticated;

revoke all on function public.zoonl_save_my_profile(text, text, text) from public, anon;
grant execute on function public.zoonl_save_my_profile(text, text, text) to authenticated;

-- Legacy RPCs accept client-supplied sender/user IDs and are not used by the app.
revoke all on function public.send_live_gift(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.zonal_send_live_gift(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.zoonl_send_live_gift(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.zoonl_equip_cosmetic(uuid, text) from public, anon, authenticated;

-- Trigger-only functions must not be directly callable through the REST API.
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.create_friendship_after_accept() from public, anon, authenticated;
revoke all on function public.validate_host_registration_source() from public, anon, authenticated;
