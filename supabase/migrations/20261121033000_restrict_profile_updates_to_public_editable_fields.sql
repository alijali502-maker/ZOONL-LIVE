-- Prevent authenticated users from promoting themselves, editing level,
-- or changing their public ZOONL identity through broad row UPDATE grants.
revoke update on table public.profiles from public, anon, authenticated;
grant update (
  username,
  display_name,
  avatar_url,
  country,
  language,
  bio,
  profile_background_url,
  updated_at
) on table public.profiles to authenticated;

-- Profile editor syncs only media and bio to the public profile.
-- Keep user_id and zoonl_id immutable to clients.
revoke update on table public.user_public_profiles from public, anon, authenticated;
grant update (avatar_url, bio, updated_at)
on table public.user_public_profiles to authenticated;
