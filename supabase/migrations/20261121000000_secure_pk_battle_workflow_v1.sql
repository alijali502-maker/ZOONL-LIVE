-- Secure ZOONL LIVE PK workflow. Client writes are routed through authenticated RPCs.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.pk_can_view_battle(p_battle_id integer)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, auth
as $$
  select auth.uid() is not null and exists (
    select 1 from public.pk_battles b
    where b.id = p_battle_id and (
      b.battle_status = 'active' or b.created_by = auth.uid()
      or exists (select 1 from public.pk_participants p where p.battle_id=b.id and p.user_id=auth.uid())
      or exists (select 1 from public.pk_invitations i where i.battle_id=b.id and i.invited_user_id=auth.uid() and i.invitation_status='pending')
    )
  );
$$;
grant usage on schema private to authenticated;
grant execute on function private.pk_can_view_battle(integer) to authenticated;

alter table public.pk_battles enable row level security;
alter table public.pk_participants enable row level security;
alter table public.pk_invitations enable row level security;
alter table public.pk_score_events enable row level security;
alter table public.pk_results enable row level security;
alter table public.pk_rankings enable row level security;

drop policy if exists pk_battles_read_authorized on public.pk_battles;
create policy pk_battles_read_authorized on public.pk_battles for select to authenticated using (private.pk_can_view_battle(id));
drop policy if exists pk_participants_read_authorized on public.pk_participants;
create policy pk_participants_read_authorized on public.pk_participants for select to authenticated using (private.pk_can_view_battle(battle_id));
drop policy if exists pk_invitations_read_own on public.pk_invitations;
create policy pk_invitations_read_own on public.pk_invitations for select to authenticated using (inviter_id=(select auth.uid()) or invited_user_id=(select auth.uid()));
drop policy if exists pk_score_events_read_authorized on public.pk_score_events;
create policy pk_score_events_read_authorized on public.pk_score_events for select to authenticated using (private.pk_can_view_battle(battle_id));
drop policy if exists pk_results_read_authenticated on public.pk_results;
create policy pk_results_read_authenticated on public.pk_results for select to authenticated using (true);
drop policy if exists pk_rankings_read_authenticated on public.pk_rankings;
create policy pk_rankings_read_authenticated on public.pk_rankings for select to authenticated using (true);

revoke insert, update, delete, truncate, references, trigger
on public.pk_battles, public.pk_participants, public.pk_invitations, public.pk_score_events, public.pk_results, public.pk_rankings
from anon, authenticated;

create table if not exists public.pk_matchmaking_queue (
  user_id uuid primary key references auth.users(id) on delete cascade,
  duration_minutes integer not null default 5 check (duration_minutes=5),
  queued_at timestamptz not null default now()
);
alter table public.pk_matchmaking_queue enable row level security;
revoke all on public.pk_matchmaking_queue from anon, authenticated;

create or replace function public.pk_create_battle(p_battle_type text,p_max_participants integer,p_duration_minutes integer)
returns integer language plpgsql security definer set search_path=pg_catalog,public,auth
as $$
declare v_user uuid:=auth.uid(); v_id integer; v_type text:=lower(trim(coalesce(p_battle_type,'')));
begin
 if v_user is null then raise exception 'LOGIN_REQUIRED'; end if;
 if v_type not in ('friend','multi') then raise exception 'INVALID_BATTLE_TYPE'; end if;
 if v_type='friend' and (p_max_participants<>2 or p_duration_minutes not between 5 and 10) then raise exception 'FRIEND_PK_REQUIRES_2_PLAYERS_AND_5_TO_10_MINUTES'; end if;
 if v_type='multi' and (p_max_participants not in (4,6) or p_duration_minutes not between 5 and 10) then raise exception 'GROUP_PK_REQUIRES_4_OR_6_PLAYERS_AND_5_TO_10_MINUTES'; end if;
 insert into public.pk_battles(battle_type,battle_status,duration_minutes,max_participants,created_by,settings)
 values(v_type,'waiting',p_duration_minutes,p_max_participants,v_user,jsonb_build_object('teams',2,'score_source','verified_gifts')) returning id into v_id;
 insert into public.pk_participants(battle_id,user_id,team_number,score,status) values(v_id,v_user,1,0,'joined');
 return v_id;
end; $$;

create or replace function public.pk_invite_user(p_battle_id integer,p_target_zoonl_id text)
returns integer language plpgsql security definer set search_path=pg_catalog,public,auth
as $$
declare v_user uuid:=auth.uid(); v_target uuid; v_battle public.pk_battles%rowtype; v_inv integer; v_count integer;
begin
 if v_user is null then raise exception 'LOGIN_REQUIRED'; end if;
 select * into v_battle from public.pk_battles where id=p_battle_id for update;
 if not found or v_battle.battle_status<>'waiting' then raise exception 'BATTLE_NOT_AVAILABLE'; end if;
 if v_battle.created_by<>v_user then raise exception 'ONLY_CREATOR_CAN_INVITE'; end if;
 select user_id into v_target from public.user_public_profiles where zoonl_id=trim(coalesce(p_target_zoonl_id,''));
 if v_target is null then raise exception 'ZOONL_ID_NOT_FOUND'; end if;
 if v_target=v_user then raise exception 'CANNOT_INVITE_SELF'; end if;
 select count(*) into v_count from public.pk_participants where battle_id=p_battle_id;
 if v_count>=v_battle.max_participants then raise exception 'BATTLE_FULL'; end if;
 if exists(select 1 from public.pk_participants where battle_id=p_battle_id and user_id=v_target) then raise exception 'ALREADY_JOINED'; end if;
 if exists(select 1 from public.pk_invitations where battle_id=p_battle_id and invited_user_id=v_target and invitation_status='pending') then raise exception 'INVITATION_ALREADY_PENDING'; end if;
 insert into public.pk_invitations(battle_id,inviter_id,invited_user_id,invitation_status)
 values(p_battle_id,v_user,v_target,'pending') returning id into v_inv;
 return v_inv;
end; $$;

create or replace function public.pk_respond_invitation(p_invitation_id integer,p_accept boolean)
returns integer language plpgsql security definer set search_path=pg_catalog,public,auth
as $$
declare v_user uuid:=auth.uid(); v_inv public.pk_invitations%rowtype; v_battle public.pk_battles%rowtype; v_one integer; v_two integer;
begin
 if v_user is null then raise exception 'LOGIN_REQUIRED'; end if;
 select * into v_inv from public.pk_invitations where id=p_invitation_id and invited_user_id=v_user and invitation_status='pending' for update;
 if not found then raise exception 'INVITATION_NOT_AVAILABLE'; end if;
 select * into v_battle from public.pk_battles where id=v_inv.battle_id for update;
 if not found or v_battle.battle_status<>'waiting' then raise exception 'BATTLE_NOT_AVAILABLE'; end if;
 if not p_accept then
   update public.pk_invitations set invitation_status='rejected',responded_at=now() where id=p_invitation_id;
   return v_battle.id;
 end if;
 if exists(select 1 from public.pk_participants where battle_id=v_battle.id and user_id=v_user) then raise exception 'ALREADY_JOINED'; end if;
 if (select count(*) from public.pk_participants where battle_id=v_battle.id)>=v_battle.max_participants then raise exception 'BATTLE_FULL'; end if;
 select count(*) filter(where team_number=1),count(*) filter(where team_number=2) into v_one,v_two from public.pk_participants where battle_id=v_battle.id;
 insert into public.pk_participants(battle_id,user_id,team_number,score,status)
 values(v_battle.id,v_user,case when coalesce(v_one,0)<=coalesce(v_two,0) then 1 else 2 end,0,'joined');
 update public.pk_invitations set invitation_status='accepted',responded_at=now() where id=p_invitation_id;
 return v_battle.id;
end; $$;

create or replace function public.pk_join_random_queue()
returns integer language plpgsql security definer set search_path=pg_catalog,public,auth
as $$
declare v_user uuid:=auth.uid(); v_opponent uuid; v_id integer;
begin
 if v_user is null then raise exception 'LOGIN_REQUIRED'; end if;
 perform pg_advisory_xact_lock(78210451);
 select user_id into v_opponent from public.pk_matchmaking_queue
 where user_id<>v_user and duration_minutes=5 order by queued_at for update skip locked limit 1;
 if v_opponent is null then
   insert into public.pk_matchmaking_queue(user_id,duration_minutes,queued_at) values(v_user,5,now())
   on conflict(user_id) do update set duration_minutes=5;
   return null;
 end if;
 delete from public.pk_matchmaking_queue where user_id in(v_user,v_opponent);
 insert into public.pk_battles(battle_type,battle_status,duration_minutes,max_participants,created_by,settings)
 values('random','waiting',5,2,v_opponent,jsonb_build_object('teams',2,'score_source','verified_gifts')) returning id into v_id;
 insert into public.pk_participants(battle_id,user_id,team_number,score,status)
 values(v_id,v_opponent,1,0,'joined'),(v_id,v_user,2,0,'joined');
 return v_id;
end; $$;

create or replace function public.pk_leave_random_queue()
returns boolean language plpgsql security definer set search_path=pg_catalog,public,auth
as $$
begin
 if auth.uid() is null then raise exception 'LOGIN_REQUIRED'; end if;
 delete from public.pk_matchmaking_queue where user_id=auth.uid();
 return true;
end; $$;

create or replace function public.pk_start_battle(p_battle_id integer)
returns text language plpgsql security definer set search_path=pg_catalog,public,auth
as $$
declare v_user uuid:=auth.uid(); v_battle public.pk_battles%rowtype; v_count integer;
begin
 if v_user is null then raise exception 'LOGIN_REQUIRED'; end if;
 select * into v_battle from public.pk_battles where id=p_battle_id for update;
 if not found or v_battle.battle_status<>'waiting' then return 'Battle not available'; end if;
 if v_battle.created_by<>v_user and not public.is_zoonl_owner() then raise exception 'ONLY_CREATOR_CAN_START'; end if;
 select count(*) into v_count from public.pk_participants where battle_id=p_battle_id;
 if v_count<>v_battle.max_participants then return 'Waiting for all invited players'; end if;
 if v_battle.battle_type='random' and (v_count<>2 or v_battle.duration_minutes<>5) then return 'Random PK requires 2 players and 5 minutes'; end if;
 if v_battle.battle_type='friend' and (v_count<>2 or v_battle.duration_minutes not between 5 and 10) then return 'Friend PK requires 2 players and 5-10 minutes'; end if;
 if v_battle.battle_type='multi' and (v_count not in(4,6) or v_count>coalesce(v_battle.max_participants,6) or v_battle.duration_minutes not between 5 and 10) then return 'Group PK requires 4 or 6 players and 5-10 minutes'; end if;
 update public.pk_battles set battle_status='active',started_at=now() where id=p_battle_id;
 return 'PK started';
end; $$;

create or replace function public.pk_finish_battle(p_battle_id integer)
returns text language plpgsql security definer set search_path=pg_catalog,public,auth
as $$
declare
 v_user uuid:=auth.uid(); v_battle public.pk_battles%rowtype;
 v_top bigint; v_low bigint; v_top_count integer; v_winner uuid; v_tie boolean;
 v_week date:=date_trunc('week',current_date)::date; v_month date:=date_trunc('month',current_date)::date; v_losers uuid[];
begin
 if v_user is null then raise exception 'LOGIN_REQUIRED'; end if;
 select * into v_battle from public.pk_battles where id=p_battle_id for update;
 if not found or v_battle.battle_status<>'active' then return 'Battle is not active'; end if;
 if v_battle.created_by<>v_user and not public.is_zoonl_owner() then raise exception 'ONLY_CREATOR_CAN_FINISH'; end if;
 if v_battle.started_at is null or now()<v_battle.started_at+make_interval(mins=>v_battle.duration_minutes) then return 'Battle duration has not elapsed'; end if;
 select max(score),count(*) filter(where score=(select max(score) from public.pk_participants where battle_id=p_battle_id))
 into v_top,v_top_count from public.pk_participants where battle_id=p_battle_id;
 if v_top is null then return 'No scores found'; end if;
 v_tie:=v_top_count>1;
 if not v_tie then select user_id into v_winner from public.pk_participants where battle_id=p_battle_id and score=v_top limit 1; end if;
 select coalesce(array_agg(user_id),'{}'::uuid[]) into v_losers from public.pk_participants where battle_id=p_battle_id and (v_tie or user_id<>v_winner);
 select coalesce(max(score),0) into v_low from public.pk_participants where battle_id=p_battle_id and (v_tie or user_id<>v_winner);
 update public.pk_battles set battle_status='completed',ended_at=now(),winner_user_id=v_winner where id=p_battle_id;
 insert into public.pk_results(battle_id,winner_user_id,winning_score,losing_score,loser_user_ids) values(p_battle_id,v_winner,v_top,v_low,v_losers);
 insert into public.pk_rankings(user_id,weekly_wins,monthly_wins,total_wins,total_losses,total_score,week_start,month_start,total_ties,updated_at)
 select p.user_id,
   case when not v_tie and p.user_id=v_winner then 1 else 0 end,
   case when not v_tie and p.user_id=v_winner then 1 else 0 end,
   case when not v_tie and p.user_id=v_winner then 1 else 0 end,
   case when not v_tie and p.user_id<>v_winner then 1 else 0 end,
   coalesce(p.score,0),v_week,v_month,
   case when v_tie and p.score=v_top then 1 else 0 end,now()
 from public.pk_participants p where p.battle_id=p_battle_id
 on conflict(user_id) do update set
   weekly_wins=(case when public.pk_rankings.week_start=v_week then public.pk_rankings.weekly_wins else 0 end)+excluded.weekly_wins,
   monthly_wins=(case when public.pk_rankings.month_start=v_month then public.pk_rankings.monthly_wins else 0 end)+excluded.monthly_wins,
   total_wins=public.pk_rankings.total_wins+excluded.total_wins,
   total_losses=public.pk_rankings.total_losses+excluded.total_losses,
   total_score=public.pk_rankings.total_score+excluded.total_score,
   total_ties=public.pk_rankings.total_ties+excluded.total_ties,
   week_start=v_week,month_start=v_month,updated_at=now();
 if v_tie then return 'PK completed: Tie'; end if;
 return 'PK completed: Winner and losers recorded';
end; $$;

revoke all on function public.pk_create_battle(text,integer,integer) from public,anon;
revoke all on function public.pk_invite_user(integer,text) from public,anon;
revoke all on function public.pk_respond_invitation(integer,boolean) from public,anon;
revoke all on function public.pk_join_random_queue() from public,anon;
revoke all on function public.pk_leave_random_queue() from public,anon;
revoke all on function public.pk_start_battle(integer) from public,anon;
revoke all on function public.pk_finish_battle(integer) from public,anon;
grant execute on function public.pk_create_battle(text,integer,integer) to authenticated;
grant execute on function public.pk_invite_user(integer,text) to authenticated;
grant execute on function public.pk_respond_invitation(integer,boolean) to authenticated;
grant execute on function public.pk_join_random_queue() to authenticated;
grant execute on function public.pk_leave_random_queue() to authenticated;
grant execute on function public.pk_start_battle(integer) to authenticated;
grant execute on function public.pk_finish_battle(integer) to authenticated;

do $$
begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='pk_battles') then alter publication supabase_realtime add table public.pk_battles; end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='pk_participants') then alter publication supabase_realtime add table public.pk_participants; end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='pk_invitations') then alter publication supabase_realtime add table public.pk_invitations; end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='pk_score_events') then alter publication supabase_realtime add table public.pk_score_events; end if;
 end if;
end; $$;
