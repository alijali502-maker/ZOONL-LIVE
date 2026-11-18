alter function public.pk_record_gift_score() set search_path = pg_catalog, public;
alter function public.pk_finish_battle(integer) set search_path = pg_catalog, public, auth;
alter function public.pk_start_battle(integer) set search_path = pg_catalog, public, auth;
alter function public.send_live_gift(uuid, uuid, text) set search_path = pg_catalog, public, auth;
alter function public.zonal_send_live_gift(uuid, uuid, text) set search_path = pg_catalog, public, auth;
alter function public.zoonl_send_live_gift(uuid, uuid, text) set search_path = pg_catalog, public, auth;
alter function public.zoonl_equip_cosmetic(uuid, text) set search_path = pg_catalog, public, auth;
