alter table public.agency_applications
  add column if not exists agency_type text not null default 'streamer',
  add column if not exists deposit_amount numeric(10,2) not null default 300,
  add column if not exists deposit_status text not null default 'pending',
  add column if not exists deposit_reference text,
  add column if not exists deposit_receipt_path text,
  add column if not exists review_note text,
  add column if not exists reviewed_by uuid references auth.users(id),
  add column if not exists agency_id uuid references public.agencies(id);

alter table public.agency_applications
  drop constraint if exists agency_applications_type_check;
alter table public.agency_applications
  add constraint agency_applications_type_check
  check (agency_type in ('streamer','topup','both'));
alter table public.agency_applications
  drop constraint if exists agency_applications_deposit_check;
alter table public.agency_applications
  add constraint agency_applications_deposit_check
  check (deposit_amount=300 and deposit_status in ('pending','verified','rejected'));

alter table public.agencies
  add column if not exists agency_type text not null default 'streamer';
alter table public.agencies
  drop constraint if exists agencies_type_check;
alter table public.agencies
  add constraint agencies_type_check check (agency_type in ('streamer','topup','both'));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('agency-documents-private','agency-documents-private',false,20971520,
       array['image/jpeg','image/png','application/pdf'])
on conflict(id) do update set public=false,file_size_limit=20971520,
  allowed_mime_types=array['image/jpeg','image/png','application/pdf'];

drop policy if exists agency_docs_upload_own on storage.objects;
create policy agency_docs_upload_own on storage.objects
for insert to authenticated
with check (
  bucket_id='agency-documents-private'
  and (storage.foldername(name))[1]=(select auth.uid())::text
);
drop policy if exists agency_docs_read_own_or_owner on storage.objects;
create policy agency_docs_read_own_or_owner on storage.objects
for select to authenticated
using (
  bucket_id='agency-documents-private'
  and (
    (storage.foldername(name))[1]=(select auth.uid())::text
    or public.is_zoonl_owner()
    or public.is_zoonl_admin_allowed('manage_agencies')
  )
);
drop policy if exists agency_docs_delete_own on storage.objects;
create policy agency_docs_delete_own on storage.objects
for delete to authenticated
using (
  bucket_id='agency-documents-private'
  and (storage.foldername(name))[1]=(select auth.uid())::text
);

drop policy if exists agency_applications_submit on public.agency_applications;
create policy agency_applications_submit on public.agency_applications
for insert to authenticated
with check (
  applicant_id=(select auth.uid())
  and application_status='pending'
  and deposit_status='pending'
  and deposit_amount=300
);
drop policy if exists agency_applications_owner_or_admin_read on public.agency_applications;
create policy agency_applications_owner_or_admin_read on public.agency_applications
for select to authenticated
using (
  applicant_id=(select auth.uid())
  or public.is_zoonl_owner()
  or public.is_zoonl_admin_allowed('manage_agencies')
);
revoke insert,update,delete on public.agency_applications from anon,authenticated;

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
set search_path=pg_catalog,public,auth
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

create or replace function public.owner_set_agency_deposit_status(
  p_application_id uuid,
  p_deposit_status text,
  p_review_note text default null
)
returns boolean
language plpgsql
security definer
set search_path=pg_catalog,public,auth
as $$
declare v_status text:=lower(trim(coalesce(p_deposit_status,'')));
begin
  if auth.uid() is null or not public.is_zoonl_owner() then raise exception 'OWNER_ONLY'; end if;
  if v_status not in ('verified','rejected','pending') then raise exception 'INVALID_DEPOSIT_STATUS'; end if;
  update public.agency_applications
     set deposit_status=v_status,
         review_note=coalesce(nullif(trim(p_review_note),''),review_note)
   where id=p_application_id;
  if not found then raise exception 'APPLICATION_NOT_FOUND'; end if;
  return true;
end;
$$;

create or replace function public.owner_review_agency_application(
  p_application_id uuid,
  p_decision text,
  p_review_note text default null
)
returns jsonb
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
      (agency_name,agency_code,agency_status,commission_percent,owner_id,agency_type)
    values
      (v_app.proposed_name,v_code,'approved',10,auth.uid(),v_app.agency_type)
    returning id into v_agency_id;
    insert into public.agency_registration_codes(agency_id,code,is_active)
    values(v_agency_id,v_code,true);
  end if;

  update public.agency_applications
     set application_status=v_decision,
         reviewed_at=now(),
         reviewed_by=auth.uid(),
         review_note=coalesce(nullif(trim(p_review_note),''),review_note),
         agency_id=v_agency_id
   where id=p_application_id;

  return jsonb_build_object(
    'success',true,
    'application_id',p_application_id,
    'application_status',v_decision,
    'agency_id',v_agency_id,
    'agency_code',v_code
  );
end;
$$;

revoke all on function public.submit_agency_application(text,text,jsonb,text,text) from public,anon;
revoke all on function public.owner_set_agency_deposit_status(uuid,text,text) from public,anon;
revoke all on function public.owner_review_agency_application(uuid,text,text) from public,anon;
grant execute on function public.submit_agency_application(text,text,jsonb,text,text) to authenticated;
grant execute on function public.owner_set_agency_deposit_status(uuid,text,text) to authenticated;
grant execute on function public.owner_review_agency_application(uuid,text,text) to authenticated;
