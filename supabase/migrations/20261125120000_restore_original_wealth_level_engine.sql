-- Restore the original ZOONL wealth engine.
-- Canonical progression: profiles.wealth_exp + profiles.wealth_level + wealth_levels.
-- Every committed gift_sends row credits the sender's lifetime wealth EXP exactly once.

CREATE OR REPLACE FUNCTION public.sync_user_wealth_level()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.owner_control_settings o
    WHERE o.id = 1 AND o.owner_user_id = NEW.id
  ) THEN
    NEW.wealth_level := 100;
  ELSE
    NEW.wealth_level := public.calculate_wealth_level(COALESCE(NEW.wealth_exp, 0));
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.apply_gift_send_wealth_exp()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  UPDATE public.profiles
  SET wealth_exp = COALESCE(wealth_exp, 0) + NEW.total_coins
  WHERE id = NEW.sender_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_gift_send_add_wealth_exp ON public.gift_sends;
CREATE TRIGGER trg_gift_send_add_wealth_exp
AFTER INSERT ON public.gift_sends
FOR EACH ROW EXECUTE FUNCTION public.apply_gift_send_wealth_exp();

CREATE OR REPLACE FUNCTION public.zoonl_user_level(p_user_id uuid)
RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT CASE
    WHEN auth.uid() IS NULL OR p_user_id IS NULL OR p_user_id <> auth.uid() THEN 1
    WHEN EXISTS (SELECT 1 FROM public.owner_control_settings o
                 WHERE o.id = 1 AND o.owner_user_id = p_user_id) THEN 100
    ELSE COALESCE((SELECT p.wealth_level FROM public.profiles p
                   WHERE p.id = p_user_id), 1)::integer
  END;
$$;

CREATE OR REPLACE FUNCTION public.zoonl_level_for_user(p_user_id uuid)
RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT CASE
    WHEN p_user_id IS NULL THEN 1
    WHEN EXISTS (SELECT 1 FROM public.owner_control_settings o
                 WHERE o.id = 1 AND o.owner_user_id = p_user_id) THEN 100
    ELSE COALESCE((SELECT p.wealth_level FROM public.profiles p
                   WHERE p.id = p_user_id), 1)::integer
  END;
$$;

CREATE OR REPLACE FUNCTION public.zoonl_my_lifetime_gift_exp()
RETURNS bigint
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT COALESCE(p.wealth_exp, 0)::bigint
  FROM public.profiles p WHERE p.id = auth.uid();
$$;

REVOKE ALL ON FUNCTION public.apply_gift_send_wealth_exp() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.zoonl_user_level(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.zoonl_user_level(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.zoonl_level_for_user(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.zoonl_level_for_user(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.zoonl_my_lifetime_gift_exp() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.zoonl_my_lifetime_gift_exp() TO authenticated;

-- Repair the current Owner row after installing the corrected trigger.
UPDATE public.profiles p
SET wealth_level = 100
FROM public.owner_control_settings o
WHERE o.id = 1 AND p.id = o.owner_user_id;
