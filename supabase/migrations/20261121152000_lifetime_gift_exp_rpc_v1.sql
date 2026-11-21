create or replace function public.zoonl_my_lifetime_gift_exp()
returns bigint
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
  select coalesce(sum(g.total_coins), 0)::bigint
  from public.gift_sends g
  where g.sender_id = auth.uid();
$function$;
revoke all on function public.zoonl_my_lifetime_gift_exp() from public;
grant execute on function public.zoonl_my_lifetime_gift_exp() to authenticated;
