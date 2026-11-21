create or replace function public.pk_join_random_queue()
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_user uuid := auth.uid();
  v_opponent uuid;
  v_battle_id integer;
begin
  if v_user is null then raise exception 'LOGIN_REQUIRED'; end if;
  perform pg_advisory_xact_lock(78210451);

  select user_id into v_opponent
    from public.pk_matchmaking_queue
   where user_id <> v_user and duration_minutes = 5
   order by queued_at
   for update skip locked
   limit 1;

  if v_opponent is null then
    insert into public.pk_matchmaking_queue(user_id, duration_minutes, queued_at)
    values (v_user, 5, now())
    on conflict (user_id) do update set duration_minutes = 5;
    return null;
  end if;

  delete from public.pk_matchmaking_queue where user_id in (v_user, v_opponent);

  insert into public.pk_battles
    (battle_type, battle_status, duration_minutes, max_participants, created_by, started_at, settings)
  values
    ('random', 'active', 5, 2, v_opponent, now(),
     jsonb_build_object('teams', 2, 'score_source', 'verified_gifts'))
  returning id into v_battle_id;

  insert into public.pk_participants
    (battle_id, user_id, team_number, score, status)
  values
    (v_battle_id, v_opponent, 1, 0, 'joined'),
    (v_battle_id, v_user, 2, 0, 'joined');

  return v_battle_id;
end;
$$;

create or replace function public.pk_finish_battle(p_battle_id integer)
returns text
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_user uuid := auth.uid();
  v_battle public.pk_battles%rowtype;
  v_top_score bigint;
  v_losing_score bigint;
  v_top_count integer;
  v_winner uuid;
  v_tie boolean;
  v_week date := date_trunc('week', current_date)::date;
  v_month date := date_trunc('month', current_date)::date;
  v_losers uuid[];
begin
  if v_user is null then raise exception 'LOGIN_REQUIRED'; end if;
  select * into v_battle from public.pk_battles where id = p_battle_id for update;
  if not found or v_battle.battle_status <> 'active' then return 'Battle is not active'; end if;
  if not public.is_zoonl_owner()
     and not exists (
       select 1 from public.pk_participants p
       where p.battle_id = p_battle_id and p.user_id = v_user
     ) then
    raise exception 'BATTLE_PARTICIPANT_REQUIRED';
  end if;
  if v_battle.started_at is null
     or now() < v_battle.started_at + make_interval(mins => v_battle.duration_minutes) then
    return 'Battle duration has not elapsed';
  end if;

  select max(score),
         count(*) filter (where score = (
           select max(score) from public.pk_participants where battle_id = p_battle_id
         ))
    into v_top_score, v_top_count
    from public.pk_participants where battle_id = p_battle_id;
  if v_top_score is null then return 'No scores found'; end if;

  v_tie := v_top_count > 1;
  if not v_tie then
    select user_id into v_winner from public.pk_participants
     where battle_id = p_battle_id and score = v_top_score limit 1;
  end if;

  select coalesce(array_agg(user_id), '{}'::uuid[])
    into v_losers from public.pk_participants
   where battle_id = p_battle_id and (v_tie or user_id <> v_winner);

  select coalesce(max(score), 0)
    into v_losing_score from public.pk_participants
   where battle_id = p_battle_id and (v_tie or user_id <> v_winner);

  update public.pk_battles
     set battle_status = 'completed', ended_at = now(), winner_user_id = v_winner
   where id = p_battle_id;

  insert into public.pk_results
    (battle_id, winner_user_id, winning_score, losing_score, loser_user_ids)
  values (p_battle_id, v_winner, v_top_score, v_losing_score, v_losers);

  insert into public.pk_rankings
    (user_id, weekly_wins, monthly_wins, total_wins, total_losses,
     total_score, week_start, month_start, total_ties, updated_at)
  select
    p.user_id,
    case when not v_tie and p.user_id = v_winner then 1 else 0 end,
    case when not v_tie and p.user_id = v_winner then 1 else 0 end,
    case when not v_tie and p.user_id = v_winner then 1 else 0 end,
    case when not v_tie and p.user_id <> v_winner then 1 else 0 end,
    coalesce(p.score, 0), v_week, v_month,
    case when v_tie and p.score = v_top_score then 1 else 0 end, now()
  from public.pk_participants p
  where p.battle_id = p_battle_id
  on conflict (user_id) do update set
    weekly_wins = (case when public.pk_rankings.week_start = v_week then public.pk_rankings.weekly_wins else 0 end) + excluded.weekly_wins,
    monthly_wins = (case when public.pk_rankings.month_start = v_month then public.pk_rankings.monthly_wins else 0 end) + excluded.monthly_wins,
    total_wins = public.pk_rankings.total_wins + excluded.total_wins,
    total_losses = public.pk_rankings.total_losses + excluded.total_losses,
    total_score = public.pk_rankings.total_score + excluded.total_score,
    total_ties = public.pk_rankings.total_ties + excluded.total_ties,
    week_start = v_week, month_start = v_month, updated_at = now();

  if v_tie then return 'PK completed: Tie'; end if;
  return 'PK completed: Winner and losers recorded';
end;
$$;

revoke all on function public.pk_join_random_queue() from public, anon;
revoke all on function public.pk_finish_battle(integer) from public, anon;
grant execute on function public.pk_join_random_queue() to authenticated;
grant execute on function public.pk_finish_battle(integer) to authenticated;
