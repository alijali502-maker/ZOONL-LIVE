-- Use a tightly scoped definer helper so chat mute rows never need to be exposed.
create or replace function private.is_live_room_chat_muted(
  p_room_id uuid,
  p_sender_id uuid
) returns boolean
language sql stable security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1 from public.live_room_chat_mutes mute
    where mute.room_id=p_room_id and mute.muted_user_id=p_sender_id
      and (mute.expires_at is null or mute.expires_at>now())
  );
$$;
revoke all on function private.is_live_room_chat_muted(uuid,uuid) from public,anon;
grant usage on schema private to authenticated;
grant execute on function private.is_live_room_chat_muted(uuid,uuid) to authenticated;

drop policy if exists "Authenticated users can read room chat" on public.chat_messages;
create policy "Authenticated users can read room chat"
on public.chat_messages for select to authenticated
using (not private.is_live_room_chat_muted(room_id,sender_id));
