create table if not exists public.host_verification_submissions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  country text not null,
  id_front_path text not null,
  id_back_path text not null,
  selfie_with_id_path text not null,
  verification_status text not null default 'pending'
    check (verification_status in ('pending','approved','rejected')),
  review_note text,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists host_verification_user_created_idx
  on public.host_verification_submissions(user_id,created_at desc);
alter table public.host_verification_submissions enable row level security;

drop policy if exists host_verification_read_own_or_owner on public.host_verification_submissions;
create policy host_verification_read_own_or_owner on public.host_verification_submissions
for select to authenticated
using (
  user_id=(select auth.uid())
  or public.is_zoonl_owner()
  or public.is_zoonl_admin_allowed('manage_hosts')
);
revoke insert,update,delete on public.host_verification_submissions from anon,authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('host-kyc-private','host-kyc-private',false,20971520,
       array['image/jpeg','image/png'])
on conflict(id) do update set public=false,file_size_limit=20971520,
  allowed_mime_types=array['image/jpeg','image/png'];

drop policy if exists host_kyc_upload_own on storage.objects;
create policy host_kyc_upload_own on storage.objects
for insert to authenticated
with check (
  bucket_id='host-kyc-private'
  and (storage.foldername(name))[1]=(select auth.uid())::text
);
drop policy if exists host_kyc_read_own_or_owner on storage.objects;
create policy host_kyc_read_own_or_owner on storage.objects
for select to authenticated
using (
  bucket_id='host-kyc-private'
  and (
    (storage.foldername(name))[1]=(select auth.uid())::text
    or public.is_zoonl_owner()
    or public.is_zoonl_admin_allowed('manage_hosts')
  )
);
drop policy if exists host_kyc_delete_own on storage.objects;
create policy host_kyc_delete_own on storage.objects
for delete to authenticated
using (
  bucket_id='host-kyc-private'
  and (storage.foldername(name))[1]=(select auth.uid())::text
);

create or replace function public.submit_host_verification(
  p_country text,
  p_id_front_path text,
  p_id_back_path text,
  p_selfie_with_id_path text
)
returns uuid
language plpgsql
security definer
set search_path=pg_catalog,public,auth,storage
as $$
declare
  v_user uuid:=auth.uid();
  v_id uuid;
  v_paths text[]:=array[p_id_front_path,p_id_back_path,p_selfie_with_id_path];
  v_path text;
begin
  if v_user is null then raise exception 'LOGIN_REQUIRED'; end if;
  if nullif(trim(p_country),'') is null then raise exception 'COUNTRY_REQUIRED'; end if;
  foreach v_path in array v_paths loop
    if v_path is null or v_path not like (v_user::text||'/%') then raise exception 'OWN_KYC_FILES_REQUIRED'; end if;
    if not exists(select 1 from storage.objects where bucket_id='host-kyc-private' and name=v_path) then
      raise exception 'KYC_FILE_NOT_FOUND';
    end if;
  end loop;
  if exists(select 1 from public.host_verification_submissions
    where user_id=v_user and verification_status='pending') then
    raise exception 'PENDING_HOST_VERIFICATION_EXISTS';
  end if;
  insert into public.host_verification_submissions
    (user_id,country,id_front_path,id_back_path,selfie_with_id_path,verification_status)
  values(v_user,trim(p_country),p_id_front_path,p_id_back_path,p_selfie_with_id_path,'pending')
  returning id into v_id;
  update public.profiles set country=trim(p_country) where id=v_user;
  return v_id;
end;
$$;

create or replace function public.owner_review_host_verification(
  p_submission_id uuid,
  p_decision text,
  p_review_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path=pg_catalog,public,auth
as $$
declare
  v_decision text:=lower(trim(coalesce(p_decision,'')));
  v_submission public.host_verification_submissions%rowtype;
begin
  if auth.uid() is null or not public.is_zoonl_owner() then raise exception 'OWNER_ONLY'; end if;
  if v_decision not in ('approved','rejected') then raise exception 'INVALID_DECISION'; end if;
  select * into v_submission from public.host_verification_submissions
   where id=p_submission_id for update;
  if not found then raise exception 'SUBMISSION_NOT_FOUND'; end if;
  if v_submission.verification_status<>'pending' then raise exception 'SUBMISSION_ALREADY_REVIEWED'; end if;

  update public.host_verification_submissions
     set verification_status=v_decision,
         review_note=coalesce(nullif(trim(p_review_note),''),review_note),
         reviewed_by=auth.uid(),reviewed_at=now()
   where id=p_submission_id;
  update public.profiles set is_verified=(v_decision='approved')
   where id=v_submission.user_id;

  return jsonb_build_object('success',true,'submission_id',p_submission_id,
    'user_id',v_submission.user_id,'verification_status',v_decision);
end;
$$;

revoke all on function public.submit_host_verification(text,text,text,text) from public,anon;
revoke all on function public.owner_review_host_verification(uuid,text,text) from public,anon;
grant execute on function public.submit_host_verification(text,text,text,text) to authenticated;
grant execute on function public.owner_review_host_verification(uuid,text,text) to authenticated;
