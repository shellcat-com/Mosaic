#!/usr/bin/env bash
set -euo pipefail

for mosaic_dependency in curl jq supabase; do
  if ! command -v "${mosaic_dependency}" >/dev/null 2>&1; then
    echo "Missing dependency: ${mosaic_dependency}" >&2
    exit 1
  fi
done

mosaic_api_url="${MOSAIC_SUPABASE_URL:-http://127.0.0.1:55321}"
mosaic_publishable_key="${MOSAIC_SUPABASE_PUBLISHABLE_KEY:-sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH}"

if [[ -z "${mosaic_api_url}" || -z "${mosaic_publishable_key}" ]]; then
  echo "Supabase URL and publishable key must not be empty" >&2
  exit 1
fi
if [[ "${mosaic_api_url}" != http://127.0.0.1:* && "${MOSAIC_ALLOW_REMOTE_TEST:-}" != "yes" ]]; then
  echo "Refusing to mutate a remote project. Set MOSAIC_ALLOW_REMOTE_TEST=yes explicitly." >&2
  exit 1
fi

mosaic_json_post() {
  local mosaic_path="$1"
  local mosaic_token="$2"
  local mosaic_body="$3"
  curl --fail-with-body --silent --show-error \
    -X POST "${mosaic_api_url}${mosaic_path}" \
    -H "apikey: ${mosaic_publishable_key}" \
    -H "Authorization: Bearer ${mosaic_token}" \
    -H "Content-Type: application/json" \
    --data "${mosaic_body}"
}

mosaic_new_session() {
  curl --fail-with-body --silent --show-error \
    -X POST "${mosaic_api_url}/auth/v1/signup" \
    -H "apikey: ${mosaic_publishable_key}" \
    -H "Content-Type: application/json" \
    --data '{}'
}

echo "Creating anonymous test sessions"
mosaic_session_one="$(mosaic_new_session)"
mosaic_session_two="$(mosaic_new_session)"
mosaic_token_one="$(jq -er '.access_token' <<<"${mosaic_session_one}")"
mosaic_token_two="$(jq -er '.access_token' <<<"${mosaic_session_two}")"

echo "Bootstrapping isolated organizer sandbox"
mosaic_bootstrap="$(mosaic_json_post "/functions/v1/bootstrap-demo" "${mosaic_token_one}" '{"displayName":"Integration Organizer","privacy":"anonymous"}')"
mosaic_sandbox_id="$(jq -er '.sandbox.id' <<<"${mosaic_bootstrap}")"
mosaic_invite_code="$(jq -er '.sandbox.invitation_code' <<<"${mosaic_bootstrap}")"

mosaic_mission_id="$(curl --fail-with-body --silent --show-error \
  "${mosaic_api_url}/rest/v1/missions?challenge_id=eq.${mosaic_sandbox_id}&accepted_evidence=cs.%7Breflection%7D&select=id&limit=1" \
  -H "apikey: ${mosaic_publishable_key}" \
  -H "Authorization: Bearer ${mosaic_token_one}" | jq -er '.[0].id')"
mosaic_contribution_id="$(uuidgen | tr '[:upper:]' '[:lower:]')"

echo "Preparing and finalizing a reflection"
mosaic_prepare_body="$(jq -nc \
  --arg contributionId "${mosaic_contribution_id}" \
  --arg challengeId "${mosaic_sandbox_id}" \
  --arg missionId "${mosaic_mission_id}" \
  '{contributionId:$contributionId,challengeId:$challengeId,missionId:$missionId,emotion:"hopeful",evidenceMethod:"reflection",reflection:"A synthetic integration-test reflection."}')"
mosaic_json_post "/functions/v1/prepare-contribution" "${mosaic_token_one}" "${mosaic_prepare_body}" >/dev/null

mosaic_finalize_body="$(jq -nc --arg contributionId "${mosaic_contribution_id}" \
  '{contributionId:$contributionId,includeMemory:true,showIdentity:false,exportConsent:false,storyText:"Synthetic story"}')"
mosaic_finalized="$(mosaic_json_post "/functions/v1/finalize-contribution" "${mosaic_token_one}" "${mosaic_finalize_body}")"
jq -e '.contribution.status == "self_attested"' <<<"${mosaic_finalized}" >/dev/null
mosaic_finalized_replay="$(mosaic_json_post "/functions/v1/finalize-contribution" "${mosaic_token_one}" "${mosaic_finalize_body}")"
jq -e '.contribution.status == "self_attested"' <<<"${mosaic_finalized_replay}" >/dev/null

echo "Placing the self-attested tile"
mosaic_place_body="$(jq -nc --arg contributionId "${mosaic_contribution_id}" '{contributionId:$contributionId}')"
mosaic_placed="$(mosaic_json_post "/functions/v1/place-tile" "${mosaic_token_one}" "${mosaic_place_body}")"
jq -e '.contribution.status == "placed" and (.contribution.tile_position | type == "number")' <<<"${mosaic_placed}" >/dev/null
mosaic_placed_replay="$(mosaic_json_post "/functions/v1/place-tile" "${mosaic_token_one}" "${mosaic_place_body}")"
jq -e --argjson position "$(jq '.contribution.tile_position' <<<"${mosaic_placed}")" \
  '.contribution.status == "placed" and .contribution.tile_position == $position' <<<"${mosaic_placed_replay}" >/dev/null

echo "Moderating a seeded submission twice without duplicating its audit"
mosaic_pending_id="$(curl --fail-with-body --silent --show-error \
  "${mosaic_api_url}/rest/v1/contributions?challenge_id=eq.${mosaic_sandbox_id}&status=eq.pending_review&select=id&limit=1" \
  -H "apikey: ${mosaic_publishable_key}" \
  -H "Authorization: Bearer ${mosaic_token_one}" | jq -er '.[0].id')"
mosaic_moderate_body="$(jq -nc --arg contributionId "${mosaic_pending_id}" \
  '{contributionId:$contributionId,evidenceDecision:"approved"}')"
mosaic_json_post "/functions/v1/moderate-contribution" "${mosaic_token_one}" "${mosaic_moderate_body}" >/dev/null
mosaic_json_post "/functions/v1/moderate-contribution" "${mosaic_token_one}" "${mosaic_moderate_body}" >/dev/null
mosaic_audit_count="$(curl --fail-with-body --silent --show-error \
  "${mosaic_api_url}/rest/v1/moderation_actions?contribution_id=eq.${mosaic_pending_id}&decision=eq.approved&select=id" \
  -H "apikey: ${mosaic_publishable_key}" \
  -H "Authorization: Bearer ${mosaic_token_one}" | jq 'length')"
if [[ "${mosaic_audit_count}" != "1" ]]; then
  echo "Moderation replay created ${mosaic_audit_count} audit rows; expected exactly one" >&2
  exit 1
fi

echo "Joining with a second anonymous participant"
mosaic_join_body="$(jq -nc --arg code "${mosaic_invite_code}" \
  '{code:$code,displayName:"Integration Participant",privacy:"anonymous"}')"

echo "Resolving a sanitized invitation without creating membership"
mosaic_preview_body="$(jq -nc --arg code "${mosaic_invite_code}" '{code:$code}')"
mosaic_preview="$(mosaic_json_post "/functions/v1/resolve-invitation" "${mosaic_token_two}" "${mosaic_preview_body}")"
jq -e --arg challengeId "${mosaic_sandbox_id}" \
  '.invitation.challenge_id == $challengeId and .invitation.name == "Judge Sandbox"
   and (.invitation | keys | sort) == (["challenge_id","code","goal","group_name","name","purpose","reveal_at","start_at","status","theme"] | sort)' \
  <<<"${mosaic_preview}" >/dev/null
mosaic_membership_before="$(curl --fail-with-body --silent --show-error \
  "${mosaic_api_url}/rest/v1/challenge_members?challenge_id=eq.${mosaic_sandbox_id}&select=challenge_id" \
  -H "apikey: ${mosaic_publishable_key}" \
  -H "Authorization: Bearer ${mosaic_token_two}")"
if [[ "$(jq 'length' <<<"${mosaic_membership_before}")" != "0" ]]; then
  echo "Invitation preview unexpectedly created challenge membership" >&2
  exit 1
fi

mosaic_joined="$(mosaic_json_post "/functions/v1/join-challenge" "${mosaic_token_two}" "${mosaic_join_body}")"
jq -e --arg challengeId "${mosaic_sandbox_id}" '.challenge.id == $challengeId' <<<"${mosaic_joined}" >/dev/null
mosaic_joined_replay="$(mosaic_json_post "/functions/v1/join-challenge" "${mosaic_token_two}" "${mosaic_join_body}")"
jq -e --arg challengeId "${mosaic_sandbox_id}" '.challenge.id == $challengeId' <<<"${mosaic_joined_replay}" >/dev/null
mosaic_membership_after="$(curl --fail-with-body --silent --show-error \
  "${mosaic_api_url}/rest/v1/challenge_members?challenge_id=eq.${mosaic_sandbox_id}&select=challenge_id,display_name,privacy" \
  -H "apikey: ${mosaic_publishable_key}" \
  -H "Authorization: Bearer ${mosaic_token_two}")"
jq -e 'length == 1 and .[0].display_name == "Guest participant" and .[0].privacy == "anonymous"' \
  <<<"${mosaic_membership_after}" >/dev/null

echo "Checking organizer authorization and triggering reveal"
mosaic_reveal_body="$(jq -nc --arg challengeId "${mosaic_sandbox_id}" '{challengeId:$challengeId,revealNow:true}')"
if mosaic_json_post "/functions/v1/set-reveal" "${mosaic_token_two}" "${mosaic_reveal_body}" >/dev/null 2>&1; then
  echo "A participant unexpectedly gained organizer reveal access" >&2
  exit 1
fi
mosaic_revealed="$(mosaic_json_post "/functions/v1/set-reveal" "${mosaic_token_one}" "${mosaic_reveal_body}")"
jq -e '.challenge.status == "revealed"' <<<"${mosaic_revealed}" >/dev/null

echo "Two-user integration passed: join -> submit/replay -> moderate/replay -> place/replay -> role denial -> reveal"
