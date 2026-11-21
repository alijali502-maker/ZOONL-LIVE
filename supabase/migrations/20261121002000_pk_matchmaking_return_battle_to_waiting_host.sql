alter table public.pk_matchmaking_queue
  add column if not exists battle_id integer references public.pk_battles(id) on delete set null;

create index if not exists pk_matchmaking_queue_battle_id_idx
  on public.pk_matchmaking_queue(battle_id)
  where battle_id is not null;

create or replace function public.pk_join_random_queue()
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_user uuid := auth.uid();
  v_opponent uuid;
  v_existing_battle integer;
  v_battle_id integer;
begin
  if v_user is null then raise exception 'LOGIN_REQUIRED'; end if;
  perform pg_advisory_xact_lock(78210451);

  select battle_id into v_existing_battle
    from public.pk_matchmaking_queue
   where user_id = v_user
   for update;
  if v_existing_battle is not null then
    delete from public.pk_matchmaking_queue where user_id = v_user;
    return v_existing_battle;
  end if;

  select user_id into v_opponent
    from public.pk_matchmaking_queue
   where user_id <> v_user
     and duration_minutes = 5
     and battle_id is null
   order by queued_at
   for update skip locked
   limit 1;

  if v_opponent is null then
    insert into public.pk_matchmaking_queue(user_id, duration_minutes, queued_at, battle_id)
    values (v_user, 5, now(), null)
    on conflict (user_id) do update
      set duration_minutes = 5,
          queued_at = coalesce(public.pk_matchmaking_queue.queued_at, now());
    return null;
  end if;

  delete from public.pk_matchmaking_queue where user_id = v_user;

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

  update public.pk_matchmaking_queue
     set battle_id = v_battle_id
   where user_id = v_opponent;

  return v_battle_id;
end;
$$;

revoke all on function public.pk_join_random_queue() from public, anon;
grant execute on function public.pk_join_random_queue() to authenticated;
