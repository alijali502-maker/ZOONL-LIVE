do $block$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='zoonl_live_gifts' and policyname='Public read active ZOONL gifts') then
    create policy "Public read active ZOONL gifts"
      on public.zoonl_live_gifts for select to anon, authenticated
      using (project_name = 'ZOONL LIVE' and is_active = true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='zoonl_live_cosmetics' and policyname='Public read active ZOONL cosmetics') then
    create policy "Public read active ZOONL cosmetics"
      on public.zoonl_live_cosmetics for select to anon, authenticated
      using (project_name = 'ZOONL LIVE' and is_active = true);
  end if;
end;
$block$;

grant select on public.zoonl_live_gifts to anon, authenticated;
grant select on public.zoonl_live_cosmetics to anon, authenticated;

alter view public.zoonl_api_gifts_feed set (security_invoker = true);
alter view public.zoonl_api_cosmetics_feed set (security_invoker = true);
alter view public.zoonl_api_full_feed set (security_invoker = true);
