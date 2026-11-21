-- Private-safe realtime events for equipped room entry effects.
create table if not exists public.live_room_entry_events (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.live_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  entry_code text,
  created_at timestamptz not null default now()
);

create index if not exists live_room_entry_events_room_created_idx
  on public.live_room_entry_events(room_id, created_at desc);

alter table public.live_room_entry_events enable row level security;
revoke all on public.live_room_entry_events from anon, authenticated;
grant select on public.live_room_entry_events to authenticated;

drop policy if exists "Room participants read entry events" on public.live_room_entry_events;
create policy "Room participants read entry events"
  on public.live_room_entry_events for select to authenticated
  using (
    exists (
      select 1 from public.live_rooms r
      where r.id = live_room_entry_events.room_id
        and (
          (coalesce(r.is_private,false)=false and coalesce(r.is_locked,false)=false)
          or r.owner_id = (select auth.uid())
          or private.is_current_user_live_room_member(r.id)
        )
    )
  );

alter table public.live_room_entry_events replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime'
      and schemaname='public'
      and tablename='live_room_entry_events'
  ) then
    alter publication supabase_realtime add table public.live_room_entry_events;
  end if;
end $$;
