
create or replace function public.get_public_chat_badges(p_user_ids uuid[])
returns table(user_id uuid,badge_code text)
language sql
stable
security definer
set search_path=pg_catalog,public,auth
as $$
  select requested.user_id,
    case
      when exists (
        select 1 from public.zoonl_user_trials t
        where t.user_id=requested.user_id
          and t.trial_status='active'
          and t.svip_active=true
          and t.expires_at>now()
      ) then 'SVIP'
      when exists (
        select 1 from public.user_prime_memberships m
        where m.user_id=requested.user_id
          and m.is_active=true
          and (m.expires_at is null or m.expires_at>now())
      ) then 'VIP'
      else 'NONE'
    end as badge_code
  from (select distinct unnest(coalesce(p_user_ids,'{}'::uuid[])) as user_id) requested;
$$;
revoke all on function public.get_public_chat_badges(uuid[]) from public,anon;
grant execute on function public.get_public_chat_badges(uuid[]) to authenticated;
