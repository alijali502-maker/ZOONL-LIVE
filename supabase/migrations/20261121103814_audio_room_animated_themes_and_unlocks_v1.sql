-- Audio room themes: catalog, ownership, realtime room selection, and unlock RPC.
-- Applied to Supabase as migration 20261121103814.

create table if not exists public.audio_room_themes (
  theme_code text primary key,
  theme_name text not null,
  description text not null default '',
  coin_price bigint not null default 0 check (coin_price >= 0),
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

insert into public.audio_room_themes
  (theme_code, theme_name, description, coin_price, is_active, sort_order)
values
  ('aurora', 'Aurora Sky', 'Soft moving northern lights', 0, true, 1),
  ('rose_garden', 'Rose Garden', 'Floating rose petals', 0, true, 2),
  ('moonlight', 'Moonlight Lake', 'Silver moon glow and calm water', 0, true, 3),
  ('golden_palace', 'Golden Palace', 'Warm royal gold ambience', 0, true, 4),
  ('waterfall', 'Waterfall', 'Animated falling water and mist', 10000, true, 5),
  ('ocean_dream', 'Ocean Dream', 'Deep blue waves and bubbles', 15000, true, 6),
  ('sakura', 'Sakura Garden', 'Blossom petals drifting across the room', 15000, true, 7),
  ('starfall', 'Starfall', 'A slow stream of glowing stars', 20000, true, 8),
  ('rainy_window', 'Rainy Window', 'Soft animated rain streaks', 20000, true, 9),
  ('butterfly', 'Butterfly Garden', 'Floating butterfly lights', 20000, true, 10),
  ('crystal_cave', 'Crystal Cave', 'Prismatic crystal glow', 25000, true, 11),
  ('neon_city', 'Neon City', 'Animated neon skyline ambience', 25000, true, 12),
  ('cloud_dream', 'Cloud Dream', 'Slow moving pastel clouds', 30000, true, 13),
  ('ember_glow', 'Ember Glow', 'Warm floating light particles', 30000, true, 14),
  ('love_lights', 'Love Lights', 'Gentle heart-shaped light bokeh', 30000, true, 15)
on conflict (theme_code) do update set
  theme_name = excluded.theme_name,
  description = excluded.description,
  coin_price = excluded.coin_price,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order;

create table if not exists public.user_audio_room_theme_inventory (
  user_id uuid not null references auth.users(id) on delete cascade,
  theme_code text not null references public.audio_room_themes(theme_code) on delete cascade,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, theme_code)
);

alter table public.live_rooms
  add column if not exists audio_theme_code text not null default 'aurora';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'live_rooms_audio_theme_code_fkey'
      and conrelid = 'public.live_rooms'::regclass
  ) then
    alter table public.live_rooms
      add constraint live_rooms_audio_theme_code_fkey
      foreign key (audio_theme_code)
      references public.audio_room_themes(theme_code);
  end if;
end
$$;

alter table public.audio_room_themes enable row level security;
alter table public.user_audio_room_theme_inventory enable row level security;

drop policy if exists "Audio themes are readable by everyone" on public.audio_room_themes;
create policy "Audio themes are readable by everyone"
  on public.audio_room_themes for select to authenticated
  using (is_active = true);

drop policy if exists "Users read own audio theme inventory" on public.user_audio_room_theme_inventory;
create policy "Users read own audio theme inventory"
  on public.user_audio_room_theme_inventory for select to authenticated
  using (user_id = (select auth.uid()));

grant select on public.audio_room_themes to authenticated;
grant select on public.user_audio_room_theme_inventory to authenticated;

create or replace function public.unlock_audio_room_theme(p_theme_code text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_user uuid := auth.uid();
  v_theme public.audio_room_themes%rowtype;
  v_coins bigint;
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;

  select * into v_theme
  from public.audio_room_themes
  where theme_code = p_theme_code and is_active = true
  for share;

  if not found then
    raise exception 'Theme not found';
  end if;

  if v_theme.coin_price = 0 then
    return jsonb_build_object('unlocked', true, 'already_owned', true, 'theme_code', p_theme_code);
  end if;

  if exists (
    select 1 from public.user_audio_room_theme_inventory
    where user_id = v_user and theme_code = p_theme_code
  ) then
    return jsonb_build_object('unlocked', true, 'already_owned', true, 'theme_code', p_theme_code);
  end if;

  select coins into v_coins
  from public.wallets
  where user_id = v_user
  for update;

  if not found then
    raise exception 'Wallet not found';
  end if;
  if v_coins < v_theme.coin_price then
    raise exception 'Not enough coins';
  end if;

  update public.wallets
  set coins = coins - v_theme.coin_price, updated_at = now()
  where user_id = v_user;

  insert into public.wallet_transactions(
    user_id, transaction_type, currency, amount, description
  ) values (
    v_user, 'audio_theme_unlock', 'coins', -v_theme.coin_price,
    'Unlocked audio room theme: ' || v_theme.theme_name
  );

  insert into public.user_audio_room_theme_inventory(user_id, theme_code)
  values (v_user, p_theme_code);

  return jsonb_build_object(
    'unlocked', true,
    'already_owned', false,
    'theme_code', p_theme_code,
    'coins_spent', v_theme.coin_price,
    'remaining_coins', v_coins - v_theme.coin_price
  );
end;
$function$;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'live_rooms'
  ) then
    alter publication supabase_realtime add table public.live_rooms;
  end if;
end
$$;
