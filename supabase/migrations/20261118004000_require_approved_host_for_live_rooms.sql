drop policy if exists "Owners create rooms" on public.live_rooms;
create policy "Verified hosts and Owner create rooms"
on public.live_rooms
for insert
to authenticated
with check (
  owner_id = auth.uid()
  and (
    public.is_zoonl_owner()
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.is_verified = true
    )
  )
);

drop policy if exists "Owners update rooms" on public.live_rooms;
create policy "Verified hosts and Owner update own rooms"
on public.live_rooms
for update
to authenticated
using (
  owner_id = auth.uid()
  and (
    public.is_zoonl_owner()
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.is_verified = true
    )
  )
)
with check (
  owner_id = auth.uid()
  and (
    public.is_zoonl_owner()
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.is_verified = true
    )
  )
);
