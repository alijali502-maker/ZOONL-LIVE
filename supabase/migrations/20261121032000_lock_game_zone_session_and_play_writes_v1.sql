-- Game Zone currently has no server-side game transaction RPCs or reward rules.
-- Keep existing rows and read access, but block client-forged entry/score records.
drop policy if exists gz_sessions_insert on public.game_zone_sessions;
drop policy if exists gz_sessions_update on public.game_zone_sessions;
drop policy if exists gz_plays_insert on public.game_zone_plays;

revoke insert, update, delete on table public.game_zone_sessions from anon, authenticated;
revoke insert, update, delete on table public.game_zone_plays from anon, authenticated;

grant select on table public.game_zone_sessions to authenticated;
grant select on table public.game_zone_plays to authenticated;
