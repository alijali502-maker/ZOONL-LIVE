-- ZOONL LIVE canonical progression is public.wealth_levels.
-- level_definitions was an experimental duplicate and must not be recreated
-- on fresh installs after the historical migrations have run.
-- RESTRICT intentionally fails if any future schema object still depends on it.
BEGIN;
DROP TABLE IF EXISTS public.level_definitions RESTRICT;
COMMIT;
