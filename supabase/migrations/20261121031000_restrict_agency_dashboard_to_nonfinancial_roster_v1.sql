
revoke all on function public.owner_set_admin_topup_permission(text,boolean) from public,anon,authenticated;

create or replace function public.get_my_agency_dashboard()
returns jsonb
language plpgsql
security definer
set search_path=pg_catalog,public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_result jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select jsonb_build_object(
    'agencies',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',a.id,'agency_name',a.agency_name,'agency_code',a.agency_code,
        'agency_status',a.agency_status,'agency_type',a.agency_type,
        'created_at',a.created_at,'agency_zoonl_id',owner_public.zoonl_id,
        'contact_details',a.contact_details,
        'member_count',(select count(*) from public.agency_members am where am.agency_id=a.id and am.member_status='approved')
      ))
      from public.agencies a
      left join public.user_public_profiles owner_public on owner_public.user_id=a.owner_id
      where a.owner_id=v_uid
    ),'[]'::jsonb),
    'members',coalesce((
      select jsonb_agg(jsonb_build_object(
        'agency_id',a.id,'agency_name',a.agency_name,
        'user_id',am.user_id,'display_name',p.display_name,
        'zoonl_id',upp.zoonl_id,'member_role',am.member_role,
        'member_status',am.member_status,'joined_at',am.joined_at
      ))
      from public.agency_members am
      join public.agencies a on a.id=am.agency_id and a.owner_id=v_uid
      left join public.profiles p on p.id=am.user_id
      left join public.user_public_profiles upp on upp.user_id=am.user_id
    ),'[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$$;
revoke all on function public.get_my_agency_dashboard() from public,anon;
grant execute on function public.get_my_agency_dashboard() to authenticated;
