-- Level rank is earned only from lifetime gift EXP.
-- Client-editable profiles.user_level must never grant progression or Owner status.
create or replace function public.zoonl_my_level()
returns integer
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
  select case
    when public.is_zoonl_owner() then 100
    else coalesce((
      select max(d.level)
      from public.level_definitions d
      where d.level between 1 and 99
        and d.required_exp <= coalesce((
          select sum(g.total_coins)
          from public.gift_sends g
          where g.sender_id = auth.uid()
        ), 0)
    ), 1)::int
  end;
$function$;
revoke all on function public.zoonl_my_level() from public;
grant execute on function public.zoonl_my_level() to authenticated;
