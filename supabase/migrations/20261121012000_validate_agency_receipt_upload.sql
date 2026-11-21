create or replace function public.submit_agency_application(
  p_proposed_name text,
  p_agency_type text,
  p_contact_details jsonb,
  p_deposit_reference text,
  p_deposit_receipt_path text
)
returns uuid
language plpgsql
security definer
set search_path=pg_catalog,public,auth,storage
as $$
declare
  v_user uuid:=auth.uid();
  v_id uuid;
  v_type text:=lower(trim(coalesce(p_agency_type,'')));
  v_path text:=trim(coalesce(p_deposit_receipt_path,''));
begin
  if v_user is null then raise exception 'LOGIN_REQUIRED'; end if;
  if nullif(trim(p_proposed_name),'') is null then raise exception 'AGENCY_NAME_REQUIRED'; end if;
  if v_type not in ('streamer','topup','both') then raise exception 'INVALID_AGENCY_TYPE'; end if;
  if p_contact_details is null or p_contact_details='{}'::jsonb then raise exception 'CONTACT_DETAILS_REQUIRED'; end if;
  if nullif(trim(p_deposit_reference),'') is null then raise exception 'DEPOSIT_REFERENCE_REQUIRED'; end if;
  if v_path='' or v_path not like (v_user::text||'/%') then raise exception 'OWN_DEPOSIT_RECEIPT_REQUIRED'; end if;
  if not exists(select 1 from storage.objects where bucket_id='agency-documents-private' and name=v_path) then
    raise exception 'DEPOSIT_RECEIPT_FILE_NOT_FOUND';
  end if;
  if exists(select 1 from public.agency_applications
     where applicant_id=v_user and application_status='pending') then
    raise exception 'PENDING_AGENCY_APPLICATION_EXISTS';
  end if;

  insert into public.agency_applications
    (applicant_id,proposed_name,contact_details,application_status,agency_type,
     deposit_amount,deposit_status,deposit_reference,deposit_receipt_path)
  values
    (v_user,trim(p_proposed_name),p_contact_details,'pending',v_type,
     300,'pending',trim(p_deposit_reference),v_path)
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.submit_agency_application(text,text,jsonb,text,text) from public,anon;
grant execute on function public.submit_agency_application(text,text,jsonb,text,text) to authenticated;
