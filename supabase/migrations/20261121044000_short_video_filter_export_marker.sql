-- Record whether a short video's selected filter is baked into the uploaded media.
alter table public.short_videos
  add column if not exists is_filter_baked boolean not null default false;

comment on column public.short_videos.is_filter_baked is
  'True when the filter is encoded into the stored video file; false for legacy unfiltered uploads.';
