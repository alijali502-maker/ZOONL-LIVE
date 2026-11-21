create table if not exists public.zoonl_user_trials (
  user_id uuid primary key references auth.users(id) on delete cascade,
  started_at timestamptz not null default now(),
  expires_at timestamptz not null,
  trial_status text not null default 'active' check (trial_status in ('active','expired')),
  svip_active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.zoonl_user_trials enable row level security;
drop policy if exists zoonl_user_trials_read_own on public.zoonl_user_trials;
create policy zoonl_user_trials_read_own on public.zoonl_user_trials
for select to authenticated using (user_id=(select auth.uid()));
revoke insert,update,delete,truncate,references,trigger on public.zoonl_user_trials from anon,authenticated;

insert into public.zoonl_live_cosmetics
  (project_name,zoonl_item_code,zoonl_item_name,item_type,is_animated_video,
   media_url,sound_fx,color_theme_hex,duration_sec,min_level_req,coin_price,
   reward_points,is_active,sort_order)
values
  ('ZOONL LIVE','ZOONL_TRIAL_FRAME_5D','New ID Trial Frame (5 Days)','AVATAR_FRAME',false,'','','#D6B46A',432000,0,0,0,false,9001),
  ('ZOONL LIVE','ZOONL_TRIAL_ENTRY_5D','New ID Trial Entry (5 Days)','ENTRY_EFFECT',false,'','','#9360F5',432000,0,0,0,false,9002),
  ('ZOONL LIVE','ZOONL_TRIAL_BACKGROUND_5D','New ID Trial Background (5 Days)','PROFILE_BG',false,'','','#542CA0',432000,0,0,0,false,9003)
on conflict (zoonl_item_code) do update set
  project_name=excluded.project_name,
  zoonl_item_name=excluded.zoonl_item_name,
  item_type=excluded.item_type,
  duration_sec=excluded.duration_sec,
  min_level_req=0,
  coin_price=0,
  is_active=false;

create or replace function private.activate_zoonl_new_user_trial(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path=pg_catalog,public,auth
as $$
declare v_started timestamptz:=now(); v_expires timestamptz:=now()+interval '5 days';
begin
  insert into public.zoonl_user_trials(user_id,started_at,expires_at,trial_status,svip_active)
  values(p_user_id,v_started,v_expires,'active',true)
  on conflict(user_id) do nothing;
  if not found then return; end if;

  insert into public.zoonl_live_user_baggage
    (project_name,user_id,zoonl_item_code,item_type,is_equipped,acquired_via,expires_at)
  select 'ZOONL LIVE',p_user_id,c.zoonl_item_code,c.item_type,false,'NEW_ID_TRIAL',v_expires
    from public.zoonl_live_cosmetics c
   where c.project_name='ZOONL LIVE'
     and c.zoonl_item_code in ('ZOONL_TRIAL_FRAME_5D','ZOONL_TRIAL_ENTRY_5D','ZOONL_TRIAL_BACKGROUND_5D')
  on conflict(user_id,zoonl_item_code) do nothing;
end;
$$;
revoke all on function private.activate_zoonl_new_user_trial(uuid) from public,anon,authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    nullif(new.raw_user_meta_data ->> 'username', ''),
    nullif(new.raw_user_meta_data ->> 'display_name', '')
  )
  on conflict (id) do nothing;

  insert into public.wallets (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  insert into public.user_public_profiles (user_id, zoonl_id, username, bio)
  values (
    new.id,
    nextval('public.zoonl_numeric_id_seq'::regclass)::text,
    'user_' || left(replace(new.id::text, '-', ''), 12),
    ''
  )
  on conflict (user_id) do nothing;

  perform private.activate_zoonl_new_user_trial(new.id);
  return new;
end;
$function$;

create or replace function public.expire_zoonl_user_trial()
returns jsonb
language plpgsql
security definer
set search_path=pg_catalog,public,auth
as $$
declare
  v_user uuid:=auth.uid();
  v_trial public.zoonl_user_trials%rowtype;
begin
  if v_user is null then raise exception 'LOGIN_REQUIRED'; end if;
  select * into v_trial from public.zoonl_user_trials where user_id=v_user for update;
  if not found then return jsonb_build_object('has_trial',false); end if;

  if v_trial.trial_status='active' and v_trial.expires_at<=now() then
    update public.zoonl_user_trials set trial_status='expired',svip_active=false where user_id=v_user;
    update public.zoonl_live_user_baggage
       set is_equipped=false
     where user_id=v_user and project_name='ZOONL LIVE' and acquired_via='NEW_ID_TRIAL';
    update public.zoonl_live_active_styles
       set active_profile_bg_code=case when active_profile_bg_code like 'ZOONL_TRIAL_%' then null else active_profile_bg_code end,
           active_frame_code=case when active_frame_code like 'ZOONL_TRIAL_%' then null else active_frame_code end,
           active_entry_code=case when active_entry_code like 'ZOONL_TRIAL_%' then null else active_entry_code end,
           updated_at=now()
     where user_id=v_user;
    select * into v_trial from public.zoonl_user_trials where user_id=v_user;
  end if;

  return jsonb_build_object('has_trial',true,'trial_status',v_trial.trial_status,
    'svip_active',v_trial.svip_active,'started_at',v_trial.started_at,'expires_at',v_trial.expires_at);
end;
$$;
revoke all on function public.expire_zoonl_user_trial() from public,anon;
grant execute on function public.expire_zoonl_user_trial() to authenticated;

create or replace function public.equip_zoonl_cosmetic(p_item_code text)
returns jsonb
language plpgsql
security definer
set search_path=pg_catalog,public,auth
as $function$
declare
  v_user uuid:=auth.uid();
  v_item public.zoonl_live_cosmetics%rowtype;
begin
  if v_user is null then raise exception 'LOGIN_REQUIRED'; end if;
  if nullif(trim(p_item_code),'') is null then raise exception 'ITEM_CODE_REQUIRED'; end if;

  select c.* into v_item
  from public.zoonl_live_cosmetics c
  join public.zoonl_live_user_baggage b
    on b.zoonl_item_code=c.zoonl_item_code
   and b.user_id=v_user
   and b.project_name='ZOONL LIVE'
   and (b.expires_at is null or b.expires_at>now())
  where c.project_name='ZOONL LIVE'
    and c.zoonl_item_code=trim(p_item_code)
    and (c.is_active=true or b.acquired_via='NEW_ID_TRIAL')
  limit 1;

  if not found then raise exception 'ITEM_NOT_OWNED_OR_EXPIRED'; end if;

  insert into public.zoonl_live_active_styles(user_id,project_name)
  values(v_user,'ZOONL LIVE')
  on conflict(user_id) do nothing;

  update public.zoonl_live_user_baggage set is_equipped=false
   where user_id=v_user and project_name='ZOONL LIVE' and item_type=v_item.item_type;
  update public.zoonl_live_user_baggage set is_equipped=true
   where user_id=v_user and project_name='ZOONL LIVE'
     and zoonl_item_code=v_item.zoonl_item_code and (expires_at is null or expires_at>now());

  update public.zoonl_live_active_styles
     set active_profile_bg_code=case when v_item.item_type='PROFILE_BG' then v_item.zoonl_item_code else active_profile_bg_code end,
         active_frame_code=case when v_item.item_type='AVATAR_FRAME' then v_item.zoonl_item_code else active_frame_code end,
         active_entry_code=case when v_item.item_type='ENTRY_EFFECT' then v_item.zoonl_item_code else active_entry_code end,
         active_badge_code=case when v_item.item_type='ID_BADGE' then v_item.zoonl_item_code else active_badge_code end,
         active_chat_bubble_code=case when v_item.item_type='CHAT_BUBBLE' then v_item.zoonl_item_code else active_chat_bubble_code end,
         updated_at=now()
   where user_id=v_user;

  return jsonb_build_object('success',true,'item_code',v_item.zoonl_item_code,
    'item_name',v_item.zoonl_item_name,'item_type',v_item.item_type,'message','ZOONL LIVE cosmetic equipped.');
end;
$function$;
