alter table public.owner_admin_permissions
  add column if not exists max_coins_per_transaction bigint not null default 180000,
  add column if not exists daily_coin_limit bigint not null default 360000;

alter table public.owner_admin_permissions
  drop constraint if exists owner_admin_topup_limits_positive;
alter table public.owner_admin_permissions
  add constraint owner_admin_topup_limits_positive
  check (max_coins_per_transaction > 0 and daily_coin_limit >= max_coins_per_transaction);

create table if not exists public.admin_topup_usage (
  admin_user_id uuid not null references auth.users(id) on delete cascade,
  usage_date date not null default current_date,
  coins_added bigint not null default 0 check (coins_added >= 0),
  updated_at timestamptz not null default now(),
  primary key(admin_user_id,usage_date)
);
alter table public.admin_topup_usage enable row level security;
revoke all on public.admin_topup_usage from anon,authenticated;

create or replace function public.owner_set_admin_topup_limits(
  p_admin_user_id uuid,
  p_max_coins_per_transaction bigint,
  p_daily_coin_limit bigint
)
returns boolean
language plpgsql
security definer
set search_path=pg_catalog,public,auth
as $$
declare v_owner uuid;
begin
  if auth.uid() is null or not public.is_zoonl_owner() then raise exception 'OWNER_ONLY'; end if;
  if p_admin_user_id is null or p_max_coins_per_transaction<=0
     or p_daily_coin_limit<p_max_coins_per_transaction then
    raise exception 'INVALID_TOPUP_LIMITS';
  end if;
  select owner_user_id into v_owner from public.owner_control_settings where id=1;
  update public.owner_admin_permissions
     set max_coins_per_transaction=p_max_coins_per_transaction,
         daily_coin_limit=p_daily_coin_limit
   where admin_user_id=p_admin_user_id
     and permission_key='manage_topups'
     and is_allowed=true
     and granted_by=v_owner;
  if not found then raise exception 'ADMIN_TOPUP_PERMISSION_NOT_FOUND'; end if;
  return true;
end;
$$;

create or replace function public.add_zoonl_coins(
  p_zoonl_id text,
  p_amount bigint,
  p_description text default null
)
returns jsonb
language plpgsql
security definer
set search_path=pg_catalog,public,auth
as $$
declare
  v_actor uuid:=auth.uid();
  v_owner uuid;
  v_target uuid;
  v_current_coins bigint;
  v_new_balance bigint;
  v_transaction_type text;
  v_max_per_tx bigint;
  v_daily_limit bigint;
  v_daily_used bigint;
begin
  if v_actor is null then raise exception 'LOGIN_REQUIRED'; end if;
  if p_zoonl_id is null or btrim(p_zoonl_id)!~'^[0-9]+$' then raise exception 'INVALID_ZOONL_ID'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'INVALID_COIN_AMOUNT'; end if;

  select owner_user_id into v_owner from public.owner_control_settings where id=1;
  if v_owner is null then raise exception 'OWNER_NOT_CONFIGURED'; end if;

  if public.is_zoonl_owner() then
    v_transaction_type:='owner_topup';
  else
    select max_coins_per_transaction,daily_coin_limit
      into v_max_per_tx,v_daily_limit
      from public.owner_admin_permissions
     where admin_user_id=v_actor
       and permission_key='manage_topups'
       and is_allowed=true
       and granted_by=v_owner
     for update;
    if not found then raise exception 'TOPUP_PERMISSION_DENIED'; end if;
    if p_amount>v_max_per_tx then raise exception 'ADMIN_PER_TRANSACTION_LIMIT_EXCEEDED'; end if;

    insert into public.admin_topup_usage(admin_user_id,usage_date,coins_added)
    values(v_actor,current_date,0)
    on conflict(admin_user_id,usage_date) do nothing;
    select coins_added into v_daily_used
      from public.admin_topup_usage
     where admin_user_id=v_actor and usage_date=current_date
     for update;
    if coalesce(v_daily_used,0)+p_amount>v_daily_limit then
      raise exception 'ADMIN_DAILY_TOPUP_LIMIT_EXCEEDED';
    end if;
    update public.admin_topup_usage
       set coins_added=coins_added+p_amount,updated_at=now()
     where admin_user_id=v_actor and usage_date=current_date;
    v_transaction_type:='admin_topup';
  end if;

  select user_id into v_target
    from public.user_public_profiles
   where zoonl_id=btrim(p_zoonl_id);
  if v_target is null then raise exception 'TARGET_USER_NOT_FOUND'; end if;

  insert into public.wallets(user_id) values(v_target)
  on conflict(user_id) do nothing;
  select coins into v_current_coins from public.wallets where user_id=v_target for update;
  if v_current_coins is null then raise exception 'WALLET_NOT_FOUND'; end if;
  if v_current_coins::numeric+p_amount::numeric>9223372036854775807::numeric then
    raise exception 'COIN_BALANCE_LIMIT_EXCEEDED';
  end if;
  v_new_balance:=v_current_coins+p_amount;
  update public.wallets set coins=v_new_balance,updated_at=now() where user_id=v_target;

  insert into public.wallet_transactions(user_id,transaction_type,currency,amount,description)
  values(v_target,v_transaction_type,'coins',p_amount,
    coalesce(nullif(btrim(p_description),''),'Coins added by '||v_transaction_type));

  return jsonb_build_object(
    'success',true,'zoonl_id',btrim(p_zoonl_id),
    'coins_added',p_amount,'new_balance',v_new_balance,
    'transaction_type',v_transaction_type,
    'admin_max_per_transaction',case when v_transaction_type='admin_topup' then v_max_per_tx else null end,
    'admin_daily_limit',case when v_transaction_type='admin_topup' then v_daily_limit else null end
  );
end;
$$;

revoke all on function public.owner_set_admin_topup_limits(uuid,bigint,bigint) from public,anon;
revoke all on function public.add_zoonl_coins(text,bigint,text) from public,anon;
grant execute on function public.owner_set_admin_topup_limits(uuid,bigint,bigint) to authenticated;
grant execute on function public.add_zoonl_coins(text,bigint,text) to authenticated;
