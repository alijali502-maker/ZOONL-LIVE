-- Keep the SECURITY DEFINER unlock RPC unavailable to anon/PUBLIC.
revoke all on function public.unlock_audio_room_theme(text) from public;
revoke all on function public.unlock_audio_room_theme(text) from anon;
grant execute on function public.unlock_audio_room_theme(text) to authenticated;
