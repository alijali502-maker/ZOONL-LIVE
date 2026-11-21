-- Owner-priced cosmetic and Prime store.
alter table public.prime_tiers
  add column if not exists coin_price bigint not null default 0,
  add column if not exists duration_days integer not null default 30;

update public.prime_tiers
set coin_price = case id
  when 1 then 15000 when 2 then 35000 when 3 then 75000
  when 4 then 150000 when 5 then 300000 else coin_price end,
  duration_days = case when duration_days < 1 then 30 else duration_days end
where coin_price = 0;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='prime_tiers'
      and policyname='Owner manages Prime tier pricing'
  ) then
    create policy "Owner manages Prime tier pricing"
      on public.prime_tiers for all to authenticated
      using (public.is_zoonl_owner())
      with check (public.is_zoonl_owner());
  end if;
end $$;

insert into public.zoonl_live_cosmetics
  (project_name,zoonl_item_code,zoonl_item_name,item_type,is_animated_video,
   media_url,sound_fx,color_theme_hex,gradient_cycle_sec,duration_sec,
   min_level_req,coin_price,reward_points,is_active,sort_order)
select 'ZOONL LIVE','ZOONL_LUCKY_ID_01','ZOONL LIVE Lucky ID Plate',
       'ID_BADGE',true,'','',
       '#8B7CFF,#5DE1D2,#DCE8FF',6,15,1,25000,0,true,73
where not exists (
  select 1 from public.zoonl_live_cosmetics
  where project_name='ZOONL LIVE' and zoonl_item_code='ZOONL_LUCKY_ID_01'
);

create or replace function public.owner_set_zoonl_cosmetic_price(
  p_item_code text, p_coin_price bigint
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare v_item public.zoonl_live_cosmetics%rowtype;
begin
  if auth.uid() is null then raise exception 'LOGIN_REQUIRED'; end if;
  if not public.is_zoonl_owner() then raise exception 'OWNER_ONLY'; end if;
  if p_coin_price is null or p_coin_price < 0 or p_coin_price > 1000000000 then
    raise exception 'INVALID_PRICE';
  end if;
  update public.zoonl_live_cosmetics
     set coin_price=p_coin_price
   where project_name='ZOONL LIVE' and zoonl_item_code=trim(p_item_code)
   returning * into v_item;
  if not found then raise exception 'ITEM_NOT_FOUND'; end if;
  return jsonb_build_object('success',true,'item_code',v_item.zoonl_item_code,
    'coin_price',v_item.coin_price);
end;
$$;

create or replace function public.owner_set_prime_tier_price(
  p_tier_id integer, p_coin_price bigint, p_duration_days integer default 30
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare v_tier public.prime_tiers%rowtype;
begin
  if auth.uid() is null then raise exception 'LOGIN_REQUIRED'; end if;
  if not public.is_zoonl_owner() then raise exception 'OWNER_ONLY'; end if;
  if p_coin_price is null or p_coin_price < 0 or p_coin_price > 1000000000
     or p_duration_days is null or p_duration_days < 1 or p_duration_days > 3650 then
    raise exception 'INVALID_PRICE_OR_DURATION';
  end if;
  update public.prime_tiers
     set coin_price=p_coin_price, duration_days=p_duration_days
   where id=p_tier_id
   returning * into v_tier;
  if not found then raise exception 'PRIME_TIER_NOT_FOUND'; end if;
  return jsonb_build_object('success',true,'tier_id',v_tier.id,
    'coin_price',v_tier.coin_price,'duration_days',v_tier.duration_days);
end;
$$;

create or replace function public.buy_zoonl_prime_tier(p_tier_id integer)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_user uuid := auth.uid();
  v_tier public.prime_tiers%rowtype;
  v_membership_id uuid;
  v_expires_at timestamptz;
begin
  if v_user is null then raise exception 'LOGIN_REQUIRED'; end if;
  select * into v_tier from public.prime_tiers
   where id=p_tier_id and is_active=true for update;
  if not found then raise exception 'PRIME_TIER_NOT_AVAILABLE'; end if;

  if exists (
    select 1 from public.user_prime_memberships
     where user_id=v_user and prime_tier_id=p_tier_id
       and is_active=true and (expires_at is null or expires_at > now())
  ) then raise exception 'PRIME_ALREADY_ACTIVE'; end if;

  if coalesce(v_tier.coin_price,0) > 0 then
    update public.wallets
       set coins=coins-v_tier.coin_price, updated_at=now()
     where user_id=v_user and coins >= v_tier.coin_price;
    if not found then raise exception 'INSUFFICIENT_COINS'; end if;
  end if;

  update public.user_prime_memberships
     set is_active=false
   where user_id=v_user and is_active=true;

  insert into public.user_prime_memberships
    (user_id,prime_tier_id,started_at,expires_at,is_active)
  values
    (v_user,v_tier.id,now(),now()+make_interval(days=>v_tier.duration_days),true)
  returning id,expires_at into v_membership_id,v_expires_at;

  if coalesce(v_tier.coin_price,0) > 0 then
    insert into public.wallet_transactions
      (user_id,transaction_type,currency,amount,reference_id,description)
    values
      (v_user,'prime_purchase','coins',-v_tier.coin_price,v_membership_id,
       'Purchased '||v_tier.tier_name);
  end if;

  return jsonb_build_object('success',true,'membership_id',v_membership_id,
    'tier_id',v_tier.id,'tier_name',v_tier.tier_name,
    'expires_at',v_expires_at,'coin_price',v_tier.coin_price);
end;
$$;

revoke all on function public.owner_set_zoonl_cosmetic_price(text,bigint) from public, anon;
revoke all on function public.owner_set_prime_tier_price(integer,bigint,integer) from public, anon;
revoke all on function public.buy_zoonl_prime_tier(integer) from public, anon;
grant execute on function public.owner_set_zoonl_cosmetic_price(text,bigint) to authenticated;
grant execute on function public.owner_set_prime_tier_price(integer,bigint,integer) to authenticated;
grant execute on function public.buy_zoonl_prime_tier(integer) to authenticated;
