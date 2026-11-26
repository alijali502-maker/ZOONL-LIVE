create or replace function public.apply_gift_send_wealth_exp()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  v_new_exp bigint;
begin
  update public.profiles
     set wealth_exp = coalesce(wealth_exp, 0) + new.total_coins,
         gift_send_exp = coalesce(gift_send_exp, 0) + new.total_coins
   where id = new.sender_id
   returning wealth_exp into v_new_exp;

  if found then
    update public.profiles
       set wealth_level = coalesce(
         (select max(level) from public.wealth_levels
           where required_exp <= v_new_exp), 1
       ),
           user_level = coalesce(
         (select max(level) from public.wealth_levels
           where required_exp <= v_new_exp), 1
       )
     where id = new.sender_id;
  end if;
  return new;
end;
$function$;

create or replace function public.apply_gift_receive_talent_exp()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  v_new_exp bigint;
  v_new_level integer;
begin
  update public.profiles
     set talent_exp = coalesce(talent_exp, 0) + new.total_coins
   where id = new.receiver_id
   returning talent_exp into v_new_exp;

  if found then
    select coalesce(max(level), 1)
      into v_new_level
      from public.talent_levels
     where required_exp <= v_new_exp;

    update public.profiles
       set talent_level = v_new_level
     where id = new.receiver_id;
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_gift_receive_add_talent_exp on public.gift_sends;
create trigger trg_gift_receive_add_talent_exp
after insert on public.gift_sends
for each row execute function public.apply_gift_receive_talent_exp();

revoke all on function public.apply_gift_receive_talent_exp() from public, anon, authenticated;
revoke all on function public.apply_gift_send_wealth_exp() from public, anon, authenticated;
