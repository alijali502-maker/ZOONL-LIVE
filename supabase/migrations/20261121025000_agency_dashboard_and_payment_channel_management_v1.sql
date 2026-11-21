
alter table public.agencies
  add column if not exists contact_details jsonb not null default '{}'::jsonb,
  add column if not exists country text,
  add column if not exists official_topup_number text,
  add column if not exists official_whatsapp_number text;

alter table public.manual_topup_payment_channels
  add column if not exists agency_name text,
  add column if not exists agency_code text,
  add column if not exists agency_zoonl_id text;

create or replace function public.owner_upsert_manual_topup_channel(
  p_id uuid,
  p_label text,
  p_country text,
  p_payment_method text,
  p_account_name text,
  p_account_number text,
  p_whatsapp_number text,
  p_instructions text,
  p_agency_id uuid,
  p_is_active boolean
) returns jsonb
language plpgsql
security definer
set search_path=pg_catalog,public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_agency public.agencies%rowtype;
  v_agency_zoonl_id text;
  v_id uuid;
begin
  if v_uid is null or not public.is_zoonl_owner() then raise exception 'OWNER_ONLY'; end if;
  if length(trim(coalesce(p_label,'')))<2 or length(trim(coalesce(p_payment_method,'')))<2
     or length(trim(coalesce(p_account_name,'')))<2 or length(trim(coalesce(p_account_number,'')))<3 then
    raise exception 'PAYMENT_CHANNEL_FIELDS_REQUIRED';
  end if;
  if p_agency_id is not null then
    select * into v_agency from public.agencies where id=p_agency_id and agency_status='approved';
    if not found then raise exception 'APPROVED_AGENCY_NOT_FOUND'; end if;
    select zoonl_id into v_agency_zoonl_id from public.user_public_profiles where user_id=v_agency.owner_id;
  end if;

  if p_id is null then
    insert into public.manual_topup_payment_channels(
      label,country,payment_method,account_name,account_number,whatsapp_number,instructions,
      agency_id,agency_name,agency_code,agency_zoonl_id,is_active,created_by
    ) values (
      trim(p_label),trim(p_country),trim(p_payment_method),trim(p_account_name),trim(p_account_number),
      nullif(trim(coalesce(p_whatsapp_number,'')),''),nullif(trim(coalesce(p_instructions,'')),''),
      p_agency_id,case when p_agency_id is null then null else v_agency.agency_name end,
      case when p_agency_id is null then null else v_agency.agency_code end,
      v_agency_zoonl_id,coalesce(p_is_active,false),v_uid
    ) returning id into v_id;
  else
    update public.manual_topup_payment_channels set
      label=trim(p_label),country=trim(p_country),payment_method=trim(p_payment_method),
      account_name=trim(p_account_name),account_number=trim(p_account_number),
      whatsapp_number=nullif(trim(coalesce(p_whatsapp_number,'')),''),
      instructions=nullif(trim(coalesce(p_instructions,'')),''),
      agency_id=p_agency_id,
      agency_name=case when p_agency_id is null then null else v_agency.agency_name end,
      agency_code=case when p_agency_id is null then null else v_agency.agency_code end,
      agency_zoonl_id=v_agency_zoonl_id,is_active=coalesce(p_is_active,false),updated_at=now()
    where id=p_id returning id into v_id;
    if v_id is null then raise exception 'PAYMENT_CHANNEL_NOT_FOUND'; end if;
  end if;
  return jsonb_build_object('success',true,'channel_id',v_id);
end;
$$;

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
        'commission_percent',a.commission_percent,'created_at',a.created_at,
        'agency_zoonl_id',owner_public.zoonl_id,
        'contact_details',a.contact_details,
        'official_topup_number',a.official_topup_number,
        'official_whatsapp_number',a.official_whatsapp_number,
        'member_count',(select count(*) from public.agency_members am where am.agency_id=a.id and am.member_status='approved'),
        'gross_earnings',(select coalesce(sum(se.gross_amount),0) from public.streamer_earnings se where se.agency_id=a.id),
        'agency_commission',(select coalesce(sum(se.agency_commission),0) from public.streamer_earnings se where se.agency_id=a.id),
        'streamer_earnings',(select coalesce(sum(se.streamer_amount),0) from public.streamer_earnings se where se.agency_id=a.id)
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
        'member_status',am.member_status,'joined_at',am.joined_at,
        'total_earned',(select coalesce(sum(se.streamer_amount),0) from public.streamer_earnings se where se.streamer_id=am.user_id and se.agency_id=a.id)
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

revoke all on function public.owner_upsert_manual_topup_channel(uuid,text,text,text,text,text,text,text,uuid,boolean) from public,anon;
grant execute on function public.owner_upsert_manual_topup_channel(uuid,text,text,text,text,text,text,text,uuid,boolean) to authenticated;
revoke all on function public.get_my_agency_dashboard() from public,anon;
grant execute on function public.get_my_agency_dashboard() to authenticated;
