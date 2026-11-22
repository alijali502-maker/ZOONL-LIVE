-- Keep Game Zone wallet balances protected. No client may submit or edit
-- paid-entry game records, scores, reward grants, or inventory directly.
-- Game Zone has no verified server-side gameplay RPCs at present; its tables
-- remain readable under their existing owner/self RLS policies until a safe,
-- non-wagered implementation is shipped.

revoke all on table
  public.game_zone_games,
  public.game_zone_sessions,
  public.game_zone_plays,
  public.game_zone_reward_rules,
  public.game_zone_rewards,
  public.game_zone_inventory,
  public.game_zone_reward_history,
  public.game_zone_music
from public, anon, authenticated;

grant select on table
  public.game_zone_games,
  public.game_zone_reward_rules,
  public.game_zone_rewards,
  public.game_zone_music
to authenticated;

grant select on table
  public.game_zone_sessions,
  public.game_zone_plays,
  public.game_zone_inventory,
  public.game_zone_reward_history
to authenticated;

drop policy if exists gz_sessions_insert on public.game_zone_sessions;
drop policy if exists gz_sessions_update on public.game_zone_sessions;
drop policy if exists gz_plays_insert on public.game_zone_plays;

-- Ensure client-supplied scores and coin amounts cannot be posted.
revoke insert, update, delete, truncate, references, trigger
on table public.game_zone_sessions, public.game_zone_plays,
  public.game_zone_inventory, public.game_zone_reward_history,
  public.game_zone_reward_rules, public.game_zone_rewards,
  public.game_zone_games, public.game_zone_music
from public, anon, authenticated;

-- Keep all direct wallet mutation paths closed to app roles.
revoke insert, update, delete, truncate, references, trigger
on table public.wallets, public.wallet_transactions
from public, anon, authenticated;

revoke execute on function public.add_zoonl_coins(text,bigint,text)
from public, anon, authenticated;

revoke execute on function public.owner_set_admin_topup_limits(uuid,bigint,bigint)
from public, anon, authenticated;
