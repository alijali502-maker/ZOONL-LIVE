
drop policy if exists "Verified hosts and Owner create rooms" on public.live_rooms;
create policy "Verified hosts and Owner create rooms"
on public.live_rooms for insert to authenticated
with check (
  owner_id = (select auth.uid())
  and (
    public.is_zoonl_owner()
    or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.is_verified=true)
  )
  and (
    (coalesce(is_private,false)=false and coalesce(is_locked,false)=false)
    or public.is_zoonl_owner()
    or coalesce((select p.user_level from public.profiles p where p.id=(select auth.uid())),1) >= 10
  )
);

drop policy if exists "Verified hosts and Owner update own rooms" on public.live_rooms;
create policy "Verified hosts and Owner update own rooms"
on public.live_rooms for update to authenticated
using (
  owner_id = (select auth.uid())
  and (
    public.is_zoonl_owner()
    or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.is_verified=true)
  )
)
with check (
  owner_id = (select auth.uid())
  and (
    public.is_zoonl_owner()
    or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.is_verified=true)
  )
  and (
    (coalesce(is_private,false)=false and coalesce(is_locked,false)=false)
    or public.is_zoonl_owner()
    or coalesce((select p.user_level from public.profiles p where p.id=(select auth.uid())),1) >= 10
  )
);
