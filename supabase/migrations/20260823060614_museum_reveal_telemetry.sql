alter table public.engagement_events
  add column if not exists properties jsonb not null default '{}'::jsonb;

alter table public.engagement_events
  drop constraint if exists engagement_events_allowlist;

alter table public.engagement_events
  add constraint engagement_events_allowlist check (name in (
    'camera_impression','camera_open','shutter','review','sealed','reminder_opt_in',
    'reveal_open','recap_open','recap_export','recap_share',
    'artwork_package_generated','artwork_package_failed','artwork_prefetch_completed',
    'artwork_key_released','artwork_decrypt_failed','reveal_complete','reveal_skipped',
    'legacy_fallback_used'
  ));

create index if not exists engagement_events_museum_reveal_idx
  on public.engagement_events(name, occurred_at desc)
  where name in (
    'artwork_package_generated','artwork_package_failed','artwork_prefetch_completed',
    'artwork_key_released','artwork_decrypt_failed','reveal_complete','reveal_skipped',
    'legacy_fallback_used'
  );
