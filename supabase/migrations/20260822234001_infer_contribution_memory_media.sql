-- Contribution memories can originate from image or short-video evidence.
-- Infer their media form from the private object path without widening access.
create or replace view public.recap_sources with (security_invoker = true) as
select m.id, 'contribution'::text as origin, m.contribution_id, c.challenge_id, co.participant_id,
  case when m.show_identity then nullif(cm.display_name, '') else null end as participant_display_name,
  m.show_identity as attribution_allowed, mission.category, coalesce(m.approved_at, c.updated_at) as accepted_at,
  m.media_path, m.story_text, c.emotion::text as emotion, c.tile_position, false as is_revived,
  m.media_version, m.consent_version, (c.status in ('verified','placed','revealed')) as accepted,
  m.export_consent as recap_consent, (m.media_path is not null or m.story_text is not null) as media_exists,
  (m.deleted_at is not null) as is_deleted, (m.reported_at is not null) as is_reported,
  exists (select 1 from public.user_blocks ub where ub.blocker_id = (select auth.uid()) and ub.blocked_id = co.participant_id) as contributor_is_blocked,
  case
    when m.media_path is null then 'note'
    when right(lower(m.media_path), 4) in ('.mov', '.mp4') then 'video'
    else 'photo'
  end::text as media_kind,
  case
    when m.media_path is null then null
    when right(lower(m.media_path), 4) = '.mov' then 'video/quicktime'
    when right(lower(m.media_path), 4) = '.mp4' then 'video/mp4'
    when right(lower(m.media_path), 4) = '.png' then 'image/png'
    else 'image/jpeg'
  end::text as media_mime_type,
  null::numeric as duration_seconds
from public.memories m join public.contributions c on c.id = m.contribution_id
join public.contribution_owners co on co.contribution_id = c.id join public.missions mission on mission.id = c.mission_id
left join public.challenge_members cm on cm.challenge_id = c.challenge_id and cm.user_id = co.participant_id
join public.challenges challenge on challenge.id = c.challenge_id
where challenge.status = 'revealed' and m.review_status = 'approved' and m.export_consent
  and m.deleted_at is null and m.reported_at is null
  and not exists (select 1 from public.user_blocks ub where ub.blocker_id = (select auth.uid()) and ub.blocked_id = co.participant_id)
union all
select sm.id, 'shared_moment'::text, null::uuid, sm.challenge_id, sm.creator_id,
  case when sm.attribution = 'permitted' then nullif(cm.display_name, '') else null end,
  sm.attribution = 'permitted', sm.editorial_category, sm.created_at, sm.media_path, sm.note,
  null::text, null::integer, false, sm.media_version, sm.consent_version, true, sm.export_consent,
  (sm.media_path is not null or sm.note is not null), sm.deleted_at is not null, sm.reported_at is not null,
  exists (select 1 from public.user_blocks ub where ub.blocker_id = (select auth.uid()) and ub.blocked_id = sm.creator_id),
  sm.media_kind, sm.media_mime_type, sm.duration_seconds
from public.shared_moments sm join public.challenges c on c.id = sm.challenge_id
left join public.challenge_members cm on cm.challenge_id = sm.challenge_id and cm.user_id = sm.creator_id
where c.status = 'revealed' and sm.lifecycle = 'approved' and sm.reveal_consent and sm.export_consent
  and sm.deleted_at is null and sm.reported_at is null
  and not exists (select 1 from public.user_blocks ub where ub.blocker_id = (select auth.uid()) and ub.blocked_id = sm.creator_id);
