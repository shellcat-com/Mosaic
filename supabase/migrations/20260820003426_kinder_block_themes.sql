alter table public.challenges
  add column theme_id text not null default 'neighborhood-quilt',
  add column theme_palette_id text not null default 'signature',
  add column theme_seed integer not null default 1636670815,
  add column theme_revision integer not null default 1;

alter table public.challenges
  add constraint challenges_theme_id_format_check
    check (theme_id ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and length(theme_id) between 3 and 64),
  add constraint challenges_theme_palette_check
    check (theme_palette_id in ('signature', 'soft', 'kiln_night')),
  add constraint challenges_theme_seed_check
    check (theme_seed between 0 and 2147483647),
  add constraint challenges_theme_revision_check
    check (theme_revision between 1 and 10000);

comment on column public.challenges.theme_id is
  'Published KinderThemeCatalog identifier, validated by configure-challenge.';
comment on column public.challenges.theme_palette_id is
  'Individually tuned artwork treatment: signature, soft, or kiln_night.';
comment on column public.challenges.theme_seed is
  'Stable authored composition seed used for deterministic offline and export rendering.';
comment on column public.challenges.theme_revision is
  'Published catalog revision used for forward-compatible fallback behavior.';
