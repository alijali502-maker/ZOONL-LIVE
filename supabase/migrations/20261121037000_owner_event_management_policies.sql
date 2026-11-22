-- Owner-only event authoring. Public event and reward read policies remain unchanged.
drop policy if exists "Owner manages live events" on public.live_events;
create policy "Owner manages live events"
on public.live_events
for all
to authenticated
using (public.is_zoonl_owner())
with check (public.is_zoonl_owner());

drop policy if exists "Owner manages event rewards" on public.event_rewards;
create policy "Owner manages event rewards"
on public.event_rewards
for all
to authenticated
using (public.is_zoonl_owner())
with check (public.is_zoonl_owner());
