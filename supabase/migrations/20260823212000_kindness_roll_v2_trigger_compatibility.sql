-- Preserve the legacy approval error contract while allowing the service-role
-- finalize RPC to publish version-2 sealed moments.
create or replace function private.guard_shared_moment_update()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.creator_id <> new.creator_id or old.challenge_id <> new.challenge_id
     or old.created_at <> new.created_at or old.contribution_id is distinct from new.contribution_id then
    raise exception 'immutable shared moment ownership';
  end if;
  if not private.is_challenge_organizer(old.challenge_id) then
    if new.lifecycle not in ('upload_pending','sealed_pending_review','sealed','approved','deleted','consent_revoked') then
      raise exception 'invalid owner lifecycle transition';
    end if;
    if new.lifecycle = 'approved' and old.lifecycle <> 'approved' then
      raise exception 'only organizers approve shared moments';
    end if;
    if new.lifecycle = 'sealed' and old.lifecycle <> 'sealed'
       and coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role' then
      raise exception 'only the server can develop shared moments';
    end if;
    if old.reported_at is distinct from new.reported_at then
      raise exception 'reported state is server managed';
    end if;
    new.consent_version := old.consent_version + case
      when old.reveal_consent is distinct from new.reveal_consent
        or old.export_consent is distinct from new.export_consent then 1 else 0 end;
  end if;
  new.updated_at := now();
  return new;
end;
$$;
