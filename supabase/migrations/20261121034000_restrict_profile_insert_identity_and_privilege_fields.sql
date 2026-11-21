-- Profiles are created with safe public fields only. Level and verification
-- are assigned by trusted server workflows, never by a client insert.
revoke insert on table public.profiles from public, anon, authenticated;
grant insert (
  id,
  username,
  display_name,
  avatar_url,
  country,
  language,
  bio,
  profile_background_url,
  updated_at
) on table public.profiles to authenticated;

-- Public ZOONL IDs are allocated by the trusted account trigger/workflow.
revoke insert on table public.user_public_profiles from public, anon, authenticated;
