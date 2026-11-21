-- The unlock function checks auth.uid(), but keep the RPC off anon/PUBLIC.
revoke all on function public.unlock_audio_room_theme(text) from public;
revoke all on function public.unlock_audio_room_theme(text) from anon;
grant execute on function public.unlock_audio_room_theme(text) to authenticated;
