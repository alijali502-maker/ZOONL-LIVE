create table if not exists public.manual_topup_payment_channels (
  id uuid primary key default gen_random_uuid(),
  label text not null, country text not null default 'All',
  payment_method text not null, account_name text not null, account_number text not null,
  whatsapp_number text, instructions text, agency_id uuid references public.agencies(id) on delete set null,
  is_active boolean not null default false, created_by uuid references auth.users(id),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.manual_topup_payment_channels enable row level security;
revoke all on public.manual_topup_payment_channels from anon, authenticated;
grant select on public.manual_topup_payment_channels to authenticated;
drop policy if exists "Read active manual topup channels" on public.manual_topup_payment_channels;
create policy "Read active manual topup channels" on public.manual_topup_payment_channels for select to authenticated using (is_active=true);

create table if not exists public.manual_topup_requests (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  payment_channel_id uuid not null references public.manual_topup_payment_channels(id),
  amount_usd numeric(10,2) not null, coins bigint not null, payment_reference text not null,
  receipt_path text not null, request_status text not null default 'pending',
  reviewed_by uuid references auth.users(id), reviewed_at timestamptz, review_note text,
  created_at timestamptz not null default now(),
  constraint manual_topup_amount_tier check (amount_usd in (10,20,30,40,50,60,70,80,90,100)),
  constraint manual_topup_coins_rate check (coins = (amount_usd * 4500)::bigint),
  constraint manual_topup_status check (request_status in ('pending','approved','rejected')),
  constraint manual_topup_reference_length check (char_length(trim(payment_reference)) between 3 and 120)
);
alter table public.manual_topup_requests enable row level security;
revoke all on public.manual_topup_requests from anon, authenticated;
grant select on public.manual_topup_requests to authenticated;
drop policy if exists "Read own topup requests or authorized reviewers" on public.manual_topup_requests;
create policy "Read own topup requests or authorized reviewers" on public.manual_topup_requests for select to authenticated using (user_id=(select auth.uid()) or public.is_zoonl_owner() or public.is_zoonl_admin_allowed('manage_topups'));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('topup-receipts-private','topup-receipts-private',false,15728640,array['image/jpeg','image/png','application/pdf'])
on conflict(id) do update set public=false,file_size_limit=15728640,allowed_mime_types=array['image/jpeg','image/png','application/pdf'];
drop policy if exists topup_receipt_upload_own on storage.objects;
create policy topup_receipt_upload_own on storage.objects for insert to authenticated with check (bucket_id='topup-receipts-private' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists topup_receipt_read_own_or_reviewer on storage.objects;
create policy topup_receipt_read_own_or_reviewer on storage.objects for select to authenticated using (bucket_id='topup-receipts-private' and ((storage.foldername(name))[1]=(select auth.uid())::text or public.is_zoonl_owner() or public.is_zoonl_admin_allowed('manage_topups')));

create or replace function public.submit_manual_topup_request(p_payment_channel_id uuid,p_amount_usd numeric,p_payment_reference text,p_receipt_path text)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public,auth,storage as $$
declare v_uid uuid:=auth.uid(); v_coins bigint; v_channel public.manual_topup_payment_channels%rowtype; v_request_id uuid;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_amount_usd not in (10,20,30,40,50,60,70,80,90,100) then raise exception 'INVALID_TOPUP_PACKAGE'; end if;
 if length(trim(coalesce(p_payment_reference,'')))<3 then raise exception 'PAYMENT_REFERENCE_REQUIRED'; end if;
 if coalesce(p_receipt_path,'') not like v_uid::text||'/%' then raise exception 'INVALID_RECEIPT_PATH'; end if;
 select * into v_channel from public.manual_topup_payment_channels where id=p_payment_channel_id and is_active=true for share;
 if not found then raise exception 'PAYMENT_CHANNEL_UNAVAILABLE'; end if;
 if not exists(select 1 from storage.objects where bucket_id='topup-receipts-private' and name=p_receipt_path) then raise exception 'RECEIPT_NOT_FOUND'; end if;
 v_coins:=(p_amount_usd*4500)::bigint;
 insert into public.manual_topup_requests(user_id,payment_channel_id,amount_usd,coins,payment_reference,receipt_path)
 values(v_uid,p_payment_channel_id,p_amount_usd,v_coins,trim(p_payment_reference),p_receipt_path) returning id into v_request_id;
 return jsonb_build_object('success',true,'request_id',v_request_id,'amount_usd',p_amount_usd,'coins',v_coins,'status','pending');
end; $$;

create or replace function public.owner_review_manual_topup_request(p_request_id uuid,p_decision text,p_review_note text default null)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public,auth as $$
declare v_uid uuid:=auth.uid(); v_request public.manual_topup_requests%rowtype; v_owner boolean; v_admin boolean; v_max bigint; v_daily bigint; v_used bigint; v_decision text:=lower(trim(coalesce(p_decision,'')));
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 v_owner:=public.is_zoonl_owner(); v_admin:=public.is_zoonl_admin_allowed('manage_topups');
 if not v_owner and not v_admin then raise exception 'TOPUP_REVIEW_NOT_ALLOWED'; end if;
 if v_decision not in ('approved','rejected') then raise exception 'INVALID_DECISION'; end if;
 select * into v_request from public.manual_topup_requests where id=p_request_id for update;
 if not found then raise exception 'TOPUP_REQUEST_NOT_FOUND'; end if;
 if v_request.request_status<>'pending' then raise exception 'TOPUP_REQUEST_ALREADY_REVIEWED'; end if;
 if v_decision='approved' then
  if not v_owner then
   select max_coins_per_transaction,daily_coin_limit into v_max,v_daily from public.owner_admin_permissions where admin_user_id=v_uid and permission_key='manage_topups' and is_allowed=true;
   if v_max is null or v_request.coins>v_max then raise exception 'ADMIN_TRANSACTION_LIMIT_EXCEEDED'; end if;
   insert into public.admin_topup_usage(admin_user_id,usage_date,coins_added) values(v_uid,current_date,v_request.coins)
   on conflict(admin_user_id,usage_date) do update set coins_added=public.admin_topup_usage.coins_added+excluded.coins_added,updated_at=now()
   where public.admin_topup_usage.coins_added+excluded.coins_added<=v_daily returning coins_added into v_used;
   if v_used is null then raise exception 'ADMIN_DAILY_LIMIT_EXCEEDED'; end if;
  end if;
  insert into public.wallets(user_id,coins,diamonds) values(v_request.user_id,v_request.coins,0)
  on conflict(user_id) do update set coins=public.wallets.coins+excluded.coins,updated_at=now();
  insert into public.wallet_transactions(user_id,transaction_type,currency,amount,reference_id,description)
  values(v_request.user_id,'manual_topup','coins',v_request.coins,p_request_id,'Manual top-up approved: USD '||v_request.amount_usd::text);
 end if;
 update public.manual_topup_requests set request_status=v_decision,reviewed_by=v_uid,reviewed_at=now(),review_note=coalesce(nullif(trim(p_review_note),''),review_note) where id=p_request_id;
 return jsonb_build_object('success',true,'request_id',p_request_id,'status',v_decision,'coins_credited',case when v_decision='approved' then v_request.coins else 0 end);
end; $$;
revoke all on function public.submit_manual_topup_request(uuid,numeric,text,text) from public,anon;
grant execute on function public.submit_manual_topup_request(uuid,numeric,text,text) to authenticated;
revoke all on function public.owner_review_manual_topup_request(uuid,text,text) from public,anon;
grant execute on function public.owner_review_manual_topup_request(uuid,text,text) to authenticated;
