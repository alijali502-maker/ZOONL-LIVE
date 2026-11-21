-- Keep the original Game Zone catalog rows for audit/history, but do not
-- expose chance-prize or gambling-associated games to users.
update public.game_zone_games
set is_active = false,
    settings = coalesce(settings, '{}'::jsonb)
      || jsonb_build_object(
        'disabled_reason',
        'Unavailable: no safe, non-wagered server implementation is approved.'
      )
where game_code in ('treasure_hunt','lucky_wheel','teen_patti_solo');
