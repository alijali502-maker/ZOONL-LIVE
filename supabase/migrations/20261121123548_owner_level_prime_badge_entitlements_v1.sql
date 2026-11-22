-- Owner rank is granted only by the trusted owner-control record.
create or replace function public.zoonl_my_level()
returns integer
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
  select case
    when public.is_zoonl_owner() then 100
    else greatest(
      coalesce((select p.user_level from public.profiles p where p.id = auth.uid()), 1),
      coalesce((
        select max(d.level) from public.level_definitions d
        where d.required_exp <= coalesce((
          select sum(g.total_coins) from public.gift_sends g where g.sender_id = auth.uid()
        ), 0)
      ), 1)
    )::int
  end;
$function$;
