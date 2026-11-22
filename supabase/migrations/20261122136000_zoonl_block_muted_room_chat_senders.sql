drop policy if exists "Users can send their own room messages" on public.chat_messages;
create policy "Users can send their own room messages"
on public.chat_messages for insert to authenticated
with check (
  sender_id=(select auth.uid())
  and not private.is_live_room_chat_muted(room_id,sender_id)
);
