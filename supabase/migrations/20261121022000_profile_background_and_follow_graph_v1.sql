
alter table public.profiles
  add column if not exists profile_background_url text;

create table if not exists public.user_follows (
  id uuid primary key default gen_random_uuid(),
  follower_id uuid not null references auth.users(id) on delete cascade,
  following_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint user_follows_not_self check (follower_id <> following_id),
  constraint user_follows_unique unique (follower_id, following_id)
);
alter table public.user_follows enable row level security;
revoke all on public.user_follows from anon, authenticated;
grant select, insert, delete on public.user_follows to authenticated;
drop policy if exists "Public can read follow edges" on public.user_follows;
create policy "Public can read follow edges"
on public.user_follows for select to authenticated using (true);
drop policy if exists "Users follow from their own account" on public.user_follows;
create policy "Users follow from their own account"
on public.user_follows for insert to authenticated
with check (follower_id = (select auth.uid()) and follower_id <> following_id);
drop policy if exists "Users unfollow from their own account" on public.user_follows;
create policy "Users unfollow from their own account"
on public.user_follows for delete to authenticated
using (follower_id = (select auth.uid()));
