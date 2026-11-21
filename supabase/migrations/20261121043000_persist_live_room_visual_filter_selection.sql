-- Persist the selected pre-live visual filter so every room viewer renders the same look.
alter table public.live_rooms
  add column if not exists video_filter_code text not null default 'Natural',
  add column if not exists video_filter_strength double precision not null default 0.35;

alter table public.live_rooms
  drop constraint if exists live_rooms_video_filter_strength_check;
alter table public.live_rooms
  add constraint live_rooms_video_filter_strength_check
  check (video_filter_strength >= 0 and video_filter_strength <= 1);

alter table public.live_rooms
  drop constraint if exists live_rooms_video_filter_code_check;
alter table public.live_rooms
  add constraint live_rooms_video_filter_code_check
  check (video_filter_code in ('Natural','Warm','Cool','Mono','Rose'));
