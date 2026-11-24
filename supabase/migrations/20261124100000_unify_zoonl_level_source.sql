-- Unify all ZOONL LIVE level reads on the original level_definitions table.
-- Lifetime gift EXP remains the sum of committed gift_sends.total_coins.
-- Owner rank is derived only from owner_control_settings, never profile fields.

CREATE OR REPLACE FUNCTION public.zoonl_user_level(p_user_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
  SELECT CASE
    WHEN auth.uid() IS NULL OR p_user_id IS NULL THEN 1
    WHEN EXISTS (
      SELECT 1
      FROM public.owner_control_settings o
      WHERE o.id = 1 AND o.owner_user_id = p_user_id
    ) THEN 100
    ELSE COALESCE((
      SELECT MAX(d.level)
      FROM public.level_definitions d
      WHERE d.level BETWEEN 1 AND 99
        AND d.required_exp <= COALESCE((
          SELECT SUM(g.total_coins)
          FROM public.gift_sends g
          WHERE g.sender_id = p_user_id
        ), 0)
    ), 1)::integer
  END;
$function$;

CREATE OR REPLACE FUNCTION public.zoonl_level_for_user(p_user_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
  SELECT CASE
    WHEN p_user_id IS NULL THEN 1
    WHEN EXISTS (
      SELECT 1
      FROM public.owner_control_settings o
      WHERE o.id = 1 AND o.owner_user_id = p_user_id
    ) THEN 100
    ELSE COALESCE((
      SELECT MAX(d.level)
      FROM public.level_definitions d
      WHERE d.level BETWEEN 1 AND 99
        AND d.required_exp <= COALESCE((
          SELECT SUM(g.total_coins)
          FROM public.gift_sends g
          WHERE g.sender_id = p_user_id
        ), 0)
    ), 1)::integer
  END;
$function$;

REVOKE ALL ON FUNCTION public.zoonl_user_level(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.zoonl_user_level(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.zoonl_level_for_user(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.zoonl_level_for_user(uuid) TO authenticated;
