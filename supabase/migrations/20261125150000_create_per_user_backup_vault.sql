-- Per-user backup vault: reads the canonical owned-asset records.
-- No duplicate inventory is created; assets remain in their source tables.
create or replace function public.zoonl_backup_vault(p_user_id uuid default auth.uid())
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_target uuid := coalesce(p_user_id, auth.uid());
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if v_target is null then raise exception 'Backup owner is required'; end if;
  if v_target <> auth.uid() and not public.is_zoonl_owner() then
    raise exception 'Not allowed to view another user backup';
  end if;

  select jsonb_build_object(
    'user_id', v_target,
    'profile', coalesce((select jsonb_build_object(
      'display_name',p.display_name,'username',p.username,'avatar_url',p.avatar_url,
      'profile_background_url',p.profile_background_url,'bio',p.bio,'country',p.country,
      'wealth_level',p.wealth_level,'wealth_exp',p.wealth_exp
    ) from public.profiles p where p.id=v_target),'{}'::jsonb),
    'dp', coalesce((select jsonb_agg(jsonb_build_object(
      'type','DP','title','Profile Photo','media_url',p.avatar_url,'created_at',p.updated_at
    )) from public.profiles p where p.id=v_target and nullif(p.avatar_url,'') is not null),'[]'::jsonb),
    'profile_items', coalesce((select jsonb_agg(jsonb_build_object(
      'id',b.id,'code',b.zoonl_item_code,'item_type',b.item_type,'name',c.zoonl_item_name,
      'media_url',c.media_url,'equipped',b.is_equipped,'acquired_via',b.acquired_via,
      'expires_at',b.expires_at,'created_at',b.created_at
    ) order by b.created_at desc)
      from public.zoonl_live_user_baggage b left join public.zoonl_live_cosmetics c
      on c.project_name=b.project_name and c.zoonl_item_code=b.zoonl_item_code
      where b.user_id=v_target and b.project_name='ZOONL LIVE'
      and upper(coalesce(b.item_type,'')) in ('PROFILE_BG','BACKGROUND','AVATAR_FRAME','FRAME','BADGE')
    ),'[]'::jsonb),
    'entry', coalesce((select jsonb_agg(jsonb_build_object(
      'id',b.id,'code',b.zoonl_item_code,'item_type',b.item_type,'name',c.zoonl_item_name,
      'media_url',c.media_url,'equipped',b.is_equipped,'acquired_via',b.acquired_via,
      'expires_at',b.expires_at,'created_at',b.created_at
    ) order by b.created_at desc)
      from public.zoonl_live_user_baggage b left join public.zoonl_live_cosmetics c
      on c.project_name=b.project_name and c.zoonl_item_code=b.zoonl_item_code
      where b.user_id=v_target and b.project_name='ZOONL LIVE'
      and upper(coalesce(b.item_type,'')) in ('ENTRY','ENTRY_EFFECT','LIVE_ENTRY')
    ),'[]'::jsonb),
    'prime', coalesce((select jsonb_agg(jsonb_build_object(
      'id',m.id,'tier_id',m.prime_tier_id,'started_at',m.started_at,'expires_at',m.expires_at,
      'is_active',m.is_active,'tier_name',t.tier_name,'benefits',t.benefits
    ) order by m.started_at desc)
      from public.user_prime_memberships m left join public.prime_tiers t on t.id=m.prime_tier_id
      where m.user_id=v_target
    ),'[]'::jsonb),
    'frames', coalesce((select jsonb_agg(jsonb_build_object(
      'id',i.id,'effect_id',i.effect_id,'acquired_from',i.acquired_from,
      'acquired_at',i.acquired_at,'expires_at',i.expires_at,'effect',to_jsonb(e)
    ) order by i.acquired_at desc)
      from public.profile_frame_inventory i left join public.profile_visual_effect_catalog e on e.id=i.effect_id
      where i.user_id=v_target
    ),'[]'::jsonb),
    'visuals', coalesce((select jsonb_agg(jsonb_build_object(
      'id',v.id,'effect_id',v.effect_id,'is_enabled',v.is_enabled,
      'created_at',v.created_at,'effect',to_jsonb(e)
    ) order by v.created_at desc)
      from public.user_profile_visuals v left join public.profile_visual_effect_catalog e on e.id=v.effect_id
      where v.user_id=v_target
    ),'[]'::jsonb),
    'other_items', coalesce((select jsonb_agg(jsonb_build_object(
      'id',b.id,'code',b.zoonl_item_code,'item_type',b.item_type,'name',c.zoonl_item_name,
      'media_url',c.media_url,'equipped',b.is_equipped,'acquired_via',b.acquired_via,
      'expires_at',b.expires_at,'created_at',b.created_at
    ) order by b.created_at desc)
      from public.zoonl_live_user_baggage b left join public.zoonl_live_cosmetics c
      on c.project_name=b.project_name and c.zoonl_item_code=b.zoonl_item_code
      where b.user_id=v_target and b.project_name='ZOONL LIVE'
      and upper(coalesce(b.item_type,'')) not in
      ('PROFILE_BG','BACKGROUND','AVATAR_FRAME','FRAME','BADGE','ENTRY','ENTRY_EFFECT','LIVE_ENTRY')
    ),'[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$$;
revoke all on function public.zoonl_backup_vault(uuid) from public, anon;
grant execute on function public.zoonl_backup_vault(uuid) to authenticated;