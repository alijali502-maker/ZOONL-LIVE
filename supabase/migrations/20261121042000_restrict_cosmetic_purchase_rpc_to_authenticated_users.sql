-- Cosmetic purchase and equip require an authenticated account.
revoke all on function public.buy_zoonl_cosmetic(text) from public, anon;
grant execute on function public.buy_zoonl_cosmetic(text) to authenticated;
revoke all on function public.equip_zoonl_cosmetic(text) from public, anon;
grant execute on function public.equip_zoonl_cosmetic(text) to authenticated;
