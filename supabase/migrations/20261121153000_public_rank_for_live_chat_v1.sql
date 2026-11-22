create or replace function public.zoonl_level_for_user(p_user_id uuid)
returns integer
language sql
stable
security definer
set search_path = pg_catalog, public
as $function$
  select case
    when exists(select 1 from public.owner_control_settings o where o.owner_user_id = p_user_id) then 100
    else coalesce((
      select max(d.level)
      from public.level_definitions d
      where d.level between 1 and 99
        and d.required_exp <= coalesce((
          select sum(g.total_coins) from public.gift_sends g where g.sender_id = p_user_id
        ), 0)
    ),1)::int
  end;
$function$;
revoke all on function public.zoonl_level_for_user(uuid) from public;
grant execute on function public.zoonl_level_for_user(uuid) to authenticated;
