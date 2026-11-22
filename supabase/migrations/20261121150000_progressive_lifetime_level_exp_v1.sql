-- Progressive lifetime gift EXP thresholds for ZOONL LIVE.
-- total_coins remains the historical gift-spend ledger; this migration never alters wallets or gift history.
begin;

insert into public.level_definitions(level, required_exp, level_name, level_config)
values
(1,0,'ROOKIE 1', '{"tier":"bronze","shape":"shield","glow":"soft","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(2,50000,'ROOKIE 2', '{"tier":"bronze","shape":"shield","glow":"soft","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(3,200000,'ROOKIE 3', '{"tier":"bronze","shape":"shield","glow":"soft","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(4,500000,'ROOKIE 4', '{"tier":"bronze","shape":"shield","glow":"soft","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(5,650000,'ROOKIE 5', '{"tier":"bronze","shape":"shield","glow":"soft","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(6,1000000,'RISING 6', '{"tier":"bronze","shape":"shield","glow":"soft","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(7,1250000,'RISING 7', '{"tier":"bronze","shape":"shield","glow":"soft","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(8,1500000,'RISING 8', '{"tier":"bronze","shape":"shield","glow":"soft","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(9,1750000,'RISING 9', '{"tier":"bronze","shape":"shield","glow":"soft","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(10,2000000,'RISING 10', '{"tier":"bronze","shape":"shield","glow":"soft","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(11,4000000,'FALCON 11', '{"tier":"silver","shape":"crest","glow":"medium","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(12,6000000,'FALCON 12', '{"tier":"silver","shape":"crest","glow":"medium","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(13,8500000,'FALCON 13', '{"tier":"silver","shape":"crest","glow":"medium","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(14,11500000,'FALCON 14', '{"tier":"silver","shape":"crest","glow":"medium","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(15,15000000,'FALCON 15', '{"tier":"silver","shape":"crest","glow":"medium","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(16,19000000,'LIONHEART 16', '{"tier":"silver","shape":"crest","glow":"medium","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(17,23500000,'LIONHEART 17', '{"tier":"silver","shape":"crest","glow":"medium","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(18,28500000,'LIONHEART 18', '{"tier":"silver","shape":"crest","glow":"medium","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(19,34000000,'LIONHEART 19', '{"tier":"silver","shape":"crest","glow":"medium","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(20,40000000,'LIONHEART 20', '{"tier":"silver","shape":"crest","glow":"medium","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(21,48000000,'PALACE 21', '{"tier":"gold","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(22,58000000,'PALACE 22', '{"tier":"gold","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(23,70000000,'PALACE 23', '{"tier":"gold","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(24,84000000,'PALACE 24', '{"tier":"gold","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(25,100000000,'PALACE 25', '{"tier":"gold","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(26,118000000,'MILLIONAIRE 26', '{"tier":"gold","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(27,138000000,'MILLIONAIRE 27', '{"tier":"gold","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(28,160000000,'MILLIONAIRE 28', '{"tier":"gold","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(29,184000000,'MILLIONAIRE 29', '{"tier":"gold","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(30,210000000,'MILLIONAIRE 30', '{"tier":"gold","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(31,240000000,'SULTAN 31', '{"tier":"platinum","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(32,275000000,'SULTAN 32', '{"tier":"platinum","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(33,315000000,'SULTAN 33', '{"tier":"platinum","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(34,360000000,'SULTAN 34', '{"tier":"platinum","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(35,410000000,'SULTAN 35', '{"tier":"platinum","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(36,465000000,'ROYAL 36', '{"tier":"platinum","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(37,525000000,'ROYAL 37', '{"tier":"platinum","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(38,590000000,'ROYAL 38', '{"tier":"platinum","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(39,660000000,'ROYAL 39', '{"tier":"platinum","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(40,735000000,'ROYAL 40', '{"tier":"platinum","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(41,820000000,'EMPEROR 41', '{"tier":"diamond","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(42,915000000,'EMPEROR 42', '{"tier":"diamond","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(43,1020000000,'EMPEROR 43', '{"tier":"diamond","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(44,1135000000,'EMPEROR 44', '{"tier":"diamond","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(45,1260000000,'EMPEROR 45', '{"tier":"diamond","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(46,1395000000,'LEGEND 46', '{"tier":"diamond","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(47,1540000000,'LEGEND 47', '{"tier":"diamond","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(48,1695000000,'LEGEND 48', '{"tier":"diamond","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(49,1860000000,'LEGEND 49', '{"tier":"diamond","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(50,2035000000,'LEGEND 50', '{"tier":"diamond","shape":"winged_crest","glow":"strong","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(51,2235000000,'ELITE 51', '{"tier":"royal","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(52,2455000000,'ELITE 52', '{"tier":"royal","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(53,2695000000,'ELITE 53', '{"tier":"royal","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(54,2955000000,'ELITE 54', '{"tier":"royal","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(55,3235000000,'ELITE 55', '{"tier":"royal","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(56,3535000000,'ASCENDANT 56', '{"tier":"royal","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(57,3855000000,'ASCENDANT 57', '{"tier":"royal","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(58,4195000000,'ASCENDANT 58', '{"tier":"royal","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(59,4555000000,'ASCENDANT 59', '{"tier":"royal","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(60,4935000000,'ASCENDANT 60', '{"tier":"royal","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(61,5355000000,'TITAN 61', '{"tier":"imperial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(62,5815000000,'TITAN 62', '{"tier":"imperial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(63,6315000000,'TITAN 63', '{"tier":"imperial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(64,6855000000,'TITAN 64', '{"tier":"imperial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(65,7435000000,'TITAN 65', '{"tier":"imperial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(66,8055000000,'MYTHIC 66', '{"tier":"imperial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(67,8715000000,'MYTHIC 67', '{"tier":"imperial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(68,9415000000,'MYTHIC 68', '{"tier":"imperial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(69,10155000000,'MYTHIC 69', '{"tier":"imperial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(70,10935000000,'MYTHIC 70', '{"tier":"imperial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(71,11785000000,'IMPERIAL 71', '{"tier":"mythic","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(72,12695000000,'IMPERIAL 72', '{"tier":"mythic","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(73,13665000000,'IMPERIAL 73', '{"tier":"mythic","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(74,14695000000,'IMPERIAL 74', '{"tier":"mythic","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(75,15785000000,'IMPERIAL 75', '{"tier":"mythic","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(76,16935000000,'CELESTIAL 76', '{"tier":"mythic","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(77,18145000000,'CELESTIAL 77', '{"tier":"mythic","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(78,19415000000,'CELESTIAL 78', '{"tier":"mythic","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(79,20745000000,'CELESTIAL 79', '{"tier":"mythic","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(80,22135000000,'CELESTIAL 80', '{"tier":"mythic","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(81,23635000000,'ETERNAL 81', '{"tier":"celestial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(82,25235000000,'ETERNAL 82', '{"tier":"celestial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(83,26935000000,'ETERNAL 83', '{"tier":"celestial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(84,28735000000,'ETERNAL 84', '{"tier":"celestial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(85,30635000000,'ETERNAL 85', '{"tier":"celestial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(86,32635000000,'DIVINE 86', '{"tier":"celestial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(87,34735000000,'DIVINE 87', '{"tier":"celestial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(88,36935000000,'DIVINE 88', '{"tier":"celestial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(89,39235000000,'DIVINE 89', '{"tier":"celestial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(90,41635000000,'DIVINE 90', '{"tier":"celestial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(91,44235000000,'SUPREME 91', '{"tier":"celestial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(92,46985000000,'SUPREME 92', '{"tier":"celestial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(93,49885000000,'SUPREME 93', '{"tier":"celestial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(94,52935000000,'SUPREME 94', '{"tier":"celestial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(95,56135000000,'SUPREME 95', '{"tier":"celestial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(96,59485000000,'SOVEREIGN 96', '{"tier":"celestial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(97,62985000000,'SOVEREIGN 97', '{"tier":"celestial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(98,66635000000,'SOVEREIGN 98', '{"tier":"celestial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(99,70435000000,'SOVEREIGN 99', '{"tier":"celestial","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":false}'),
(100,74385000000,'OWNER ONLY', '{"tier":"owner","shape":"royal_crest","glow":"radiant","chat_ribbon":true,"profile_badge":true,"owner_only":true}')
on conflict (level) do update
set required_exp = excluded.required_exp,
    level_name = excluded.level_name,
    level_config = excluded.level_config;

create or replace function public.zoonl_my_level()
returns integer
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
  select case
    when public.is_zoonl_owner() then 100
    else least(99, greatest(
      coalesce((select p.user_level from public.profiles p where p.id = auth.uid()), 1),
      coalesce((
        select max(d.level)
        from public.level_definitions d
        where d.level < 100
          and d.required_exp <= coalesce((
            select sum(g.total_coins)
            from public.gift_sends g
            where g.sender_id = auth.uid()
          ), 0)
      ), 1)
    ))::int
  end;
$function$;

revoke all on function public.zoonl_my_level() from public;
grant execute on function public.zoonl_my_level() to authenticated;

commit;
