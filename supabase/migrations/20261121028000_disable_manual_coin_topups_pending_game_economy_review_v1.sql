
update public.manual_topup_payment_channels set is_active=false,updated_at=now();
revoke all on function public.submit_manual_topup_request(uuid,numeric,text,text) from public,anon,authenticated;
revoke all on function public.owner_review_manual_topup_request(uuid,text,text) from public,anon,authenticated;
revoke all on function public.owner_upsert_manual_topup_channel(uuid,text,text,text,text,text,text,text,uuid,boolean) from public,anon,authenticated;
