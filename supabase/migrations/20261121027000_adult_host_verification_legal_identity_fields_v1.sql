
alter table public.host_verification_submissions
  add column if not exists legal_name text,
  add column if not exists date_of_birth date;

drop function if exists public.submit_host_verification(text,text,text,text);

create function public.submit_host_verification(
  p_legal_name text,
  p_date_of_birth date,
  p_country text,
  p_id_front_path text,
  p_id_back_path text,
  p_selfie_with_id_path text
) returns uuid
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
  if length(trim(coalesce(p_legal_name,'')))<3 then raise exception 'LEGAL_NAME_REQUIRED'; end if;
  if p_date_of_birth is null or p_date_of_birth > (current_date - interval '18 years')::date then
    raise exception 'HOST_VERIFICATION_ADULTS_ONLY';
  end if;
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
    (user_id,legal_name,date_of_birth,country,id_front_path,id_back_path,selfie_with_id_path,verification_status)
  values(v_user,trim(p_legal_name),p_date_of_birth,trim(p_country),p_id_front_path,p_id_back_path,p_selfie_with_id_path,'pending')
  returning id into v_id;
  update public.profiles set country=trim(p_country) where id=v_user;
  return v_id;
end;
$$;
revoke all on function public.submit_host_verification(text,date,text,text,text,text) from public,anon;
grant execute on function public.submit_host_verification(text,date,text,text,text,text) to authenticated;
