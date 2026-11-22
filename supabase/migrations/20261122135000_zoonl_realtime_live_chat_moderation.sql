grant select on public.live_room_chat_mutes to authenticated;
drop policy if exists "Room participants read chat mute status" on public.live_room_chat_mutes;
create policy "Room participants read chat mute status"
on public.live_room_chat_mutes for select to authenticated
using (
  exists (
    select 1 from public.live_rooms r
    where r.id=live_room_chat_mutes.room_id
      and (r.owner_id=(select auth.uid()) or private.is_current_user_live_room_member(r.id))
  )
);
alter table public.live_room_chat_mutes replica identity full;
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public'
      and tablename='live_room_chat_mutes'
  ) then
    alter publication supabase_realtime add table public.live_room_chat_mutes;
  end if;
end $$;
