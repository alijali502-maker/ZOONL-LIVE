-- Keep the trusted Owner account on the permanent top Prime tier.
update public.user_prime_memberships
set is_active=false
where user_id=(select owner_user_id from public.owner_control_settings where id=1)
  and is_active=true
  and (prime_tier_id<>5 or expires_at is not null);

insert into public.user_prime_memberships
  (user_id,prime_tier_id,started_at,expires_at,is_active)
select s.owner_user_id,5,now(),null,true
from public.owner_control_settings s
where s.id=1 and s.owner_user_id is not null
  and exists(select 1 from public.prime_tiers t where t.id=5 and t.is_active=true)
  and not exists(
    select 1 from public.user_prime_memberships m
    where m.user_id=s.owner_user_id and m.prime_tier_id=5
      and m.is_active=true and m.expires_at is null
  );
