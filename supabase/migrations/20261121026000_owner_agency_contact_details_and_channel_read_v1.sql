
drop policy if exists "Read active manual topup channels" on public.manual_topup_payment_channels;
create policy "Read active manual topup channels"
on public.manual_topup_payment_channels for select to authenticated
using (is_active=true or public.is_zoonl_owner());

drop policy if exists "Owner reads all agencies" on public.agencies;
create policy "Owner reads all agencies"
on public.agencies for select to authenticated
using (public.is_zoonl_owner() or owner_id=(select auth.uid()));

create or replace function public.owner_review_agency_application(
  p_application_id uuid,
  p_decision text,
  p_review_note text default null
) returns jsonb
language plpgsql
security definer
set search_path=pg_catalog,public,auth
as $$
declare
  v_app public.agency_applications%rowtype;
  v_decision text:=lower(trim(coalesce(p_decision,'')));
  v_code text;
  v_agency_id uuid;
begin
  if auth.uid() is null or not public.is_zoonl_owner() then raise exception 'OWNER_ONLY'; end if;
  if v_decision not in ('approved','rejected') then raise exception 'INVALID_DECISION'; end if;
  select * into v_app from public.agency_applications where id=p_application_id for update;
  if not found then raise exception 'APPLICATION_NOT_FOUND'; end if;
  if v_app.application_status<>'pending' then raise exception 'APPLICATION_ALREADY_REVIEWED'; end if;

  if v_decision='approved' then
    if v_app.deposit_amount<>300 or v_app.deposit_status<>'verified' then
      raise exception 'DEPOSIT_MUST_BE_VERIFIED_BEFORE_APPROVAL';
    end if;
    v_code:='ZAG-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
    insert into public.agencies
      (agency_name,agency_code,agency_status,commission_percent,owner_id,agency_type,contact_details,country)
    values
      (v_app.proposed_name,v_code,'approved',10,auth.uid(),v_app.agency_type,
       coalesce(v_app.contact_details,'{}'::jsonb),
       nullif(trim(coalesce(v_app.contact_details->>'country','')),''))
    returning id into v_agency_id;
    insert into public.agency_registration_codes(agency_id,code,is_active)
    values(v_agency_id,v_code,true);
  end if;

  update public.agency_applications
     set application_status=v_decision,reviewed_at=now(),reviewed_by=auth.uid(),
         review_note=coalesce(nullif(trim(p_review_note),''),review_note),agency_id=v_agency_id
   where id=p_application_id;

  return jsonb_build_object('success',true,'application_id',p_application_id,
    'application_status',v_decision,'agency_id',v_agency_id,'agency_code',v_code);
end;
$$;
revoke all on function public.owner_review_agency_application(uuid,text,text) from public,anon;
grant execute on function public.owner_review_agency_application(uuid,text,text) to authenticated;
