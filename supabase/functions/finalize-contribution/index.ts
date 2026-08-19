import "@supabase/functions-js/edge-runtime.d.ts"
import { withSupabase } from "@supabase/server"
import { body, failure, HttpError, ok, optionalString, requiredUUID, userId } from "../_shared/mosaic.ts"

type RequestBody = {
  contributionId: string
  includeMemory?: boolean
  showIdentity?: boolean
  exportConsent?: boolean
  storyText?: string
}

export default {
  fetch: withSupabase({ auth: "user" }, async (request, ctx) => {
    try {
      const uid = userId(ctx)
      const input = await body<RequestBody>(request)
      const contributionId = requiredUUID(input.contributionId, "contributionId")
      const admin = ctx.supabaseAdmin

      const { data: owner, error: ownerError } = await admin.from("contribution_owners")
        .select("participant_id").eq("contribution_id", contributionId).maybeSingle()
      if (ownerError) throw ownerError
      if (!owner || owner.participant_id !== uid) throw new HttpError(403, "Only the contributor can finalize evidence")

      const { data: contribution, error: contributionError } = await admin.from("contributions")
        .select("id,challenge_id,mission_id,emotion,evidence_method,status,verification_level,tile_position")
        .eq("id", contributionId).single()
      if (contributionError) throw contributionError
      if (contribution.status !== "draft") return ok({ contribution })

      const { data: evidence, error: evidenceError } = await admin.from("evidence_submissions")
        .select("media_path,reflection_text,mime_type").eq("contribution_id", contributionId).single()
      if (evidenceError) throw evidenceError

      if (["photo", "video", "receipt"].includes(contribution.evidence_method)) {
        if (!evidence.media_path) throw new HttpError(409, "Prepared media path is missing")
        const parts = evidence.media_path.split("/")
        const filename = parts.pop()!
        const folder = parts.join("/")
        const { data: objects, error: listError } = await admin.storage
          .from("evidence-private").list(folder, { search: filename, limit: 1 })
        if (listError) throw listError
        if (!objects.some((item: { name: string }) => item.name === filename)) {
          throw new HttpError(409, "Evidence upload has not completed")
        }
      }

      const selfAttested = contribution.evidence_method === "reflection"
      const nextStatus = selfAttested ? "self_attested" : "pending_review"
      const { error: ownerUpdateError } = await admin.from("contribution_owners").update({
        include_memory: Boolean(input.includeMemory),
        show_identity: Boolean(input.showIdentity),
        export_consent: Boolean(input.exportConsent),
      }).eq("contribution_id", contributionId).eq("participant_id", uid)
      if (ownerUpdateError) throw ownerUpdateError

      const { error: evidenceUpdateError } = await admin.from("evidence_submissions").update({
        review_status: selfAttested ? "approved" : "pending",
      }).eq("contribution_id", contributionId)
      if (evidenceUpdateError) throw evidenceUpdateError

      if (input.includeMemory) {
        const storyText = optionalString(input.storyText, "storyText") ?? evidence.reflection_text
        const { error: memoryError } = await admin.from("memories").upsert({
          contribution_id: contributionId,
          challenge_id: contribution.challenge_id,
          story_text: storyText,
          show_identity: Boolean(input.showIdentity),
          export_consent: Boolean(input.exportConsent),
          review_status: "pending",
        }, { onConflict: "contribution_id" })
        if (memoryError) throw memoryError
      }

      const { data: updated, error: updateError } = await admin.from("contributions").update({
        status: nextStatus,
        verification_level: selfAttested ? "self_attested" : null,
        updated_at: new Date().toISOString(),
      }).eq("id", contributionId).eq("status", "draft")
        .select("id,challenge_id,mission_id,emotion,evidence_method,status,verification_level,tile_position").single()
      if (updateError) throw updateError

      return ok({ contribution: updated })
    } catch (error) {
      return failure(error)
    }
  }),
}
