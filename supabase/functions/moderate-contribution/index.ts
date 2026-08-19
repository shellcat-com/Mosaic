import "@supabase/functions-js/edge-runtime.d.ts"
import { withSupabase } from "@supabase/server"
import { assertOrganizer, body, failure, HttpError, ok, optionalString, requiredString, requiredUUID, userId } from "../_shared/mosaic.ts"

type RequestBody = {
  contributionId: string
  evidenceDecision: "approved" | "rejected"
  memoryDecision?: "approved" | "rejected"
  note?: string
}

export default {
  fetch: withSupabase({ auth: "user" }, async (request, ctx) => {
    try {
      const moderatorId = userId(ctx)
      const input = await body<RequestBody>(request)
      const contributionId = requiredUUID(input.contributionId, "contributionId")
      const decision = requiredString(input.evidenceDecision, "evidenceDecision", 10)
      if (decision !== "approved" && decision !== "rejected") throw new HttpError(400, "Invalid evidence decision")
      if (input.memoryDecision && !["approved", "rejected"].includes(input.memoryDecision)) {
        throw new HttpError(400, "Invalid memory decision")
      }

      const admin = ctx.supabaseAdmin
      const { data: contribution, error: contributionError } = await admin.from("contributions")
        .select("id,challenge_id,status,evidence_method").eq("id", contributionId).single()
      if (contributionError) throw contributionError
      await assertOrganizer(ctx, contribution.challenge_id)
      if (!["pending_review", "verified", "rejected"].includes(contribution.status)) {
        throw new HttpError(409, "Contribution is not awaiting moderation")
      }

      const now = new Date().toISOString()
      const { error: evidenceError } = await admin.from("evidence_submissions").update({
        review_status: decision,
        reviewed_by: moderatorId,
        reviewed_at: now,
      }).eq("contribution_id", contributionId)
      if (evidenceError) throw evidenceError

      const { data: updated, error: updateError } = await admin.from("contributions").update({
        status: decision === "approved" ? "verified" : "rejected",
        verification_level: decision === "approved" ? "organizer_verified" : null,
        updated_at: now,
      }).eq("id", contributionId)
        .select("id,challenge_id,mission_id,emotion,evidence_method,status,verification_level,tile_position").single()
      if (updateError) throw updateError

      const memoryDecision = decision === "rejected" ? "rejected" : input.memoryDecision
      if (memoryDecision) {
        let memoryMediaPath: string | null = null
        if (memoryDecision === "approved") {
          const { data: evidence, error: evidenceLookupError } = await admin.from("evidence_submissions")
            .select("media_path,mime_type").eq("contribution_id", contributionId).single()
          if (evidenceLookupError) throw evidenceLookupError
          if (evidence.media_path) {
            const { data: file, error: downloadError } = await admin.storage
              .from("evidence-private").download(evidence.media_path)
            if (downloadError) throw downloadError
            const extension = evidence.media_path.split(".").pop() ?? "bin"
            memoryMediaPath = `${contribution.challenge_id}/${contributionId}.${extension}`
            const { error: uploadError } = await admin.storage.from("memory-private").upload(
              memoryMediaPath,
              file,
              { contentType: evidence.mime_type ?? undefined, upsert: true },
            )
            if (uploadError) throw uploadError
          }
        }
        const { error: memoryError } = await admin.from("memories").update({
          review_status: memoryDecision,
          media_path: memoryMediaPath,
          approved_at: memoryDecision === "approved" ? now : null,
        }).eq("contribution_id", contributionId)
        if (memoryError) throw memoryError
      }

      const { error: auditError } = await admin.from("moderation_actions").upsert({
        challenge_id: contribution.challenge_id,
        contribution_id: contributionId,
        moderator_id: moderatorId,
        decision,
        note: optionalString(input.note, "note", 500),
      }, { onConflict: "contribution_id,decision", ignoreDuplicates: true })
      if (auditError) throw auditError

      return ok({ contribution: updated })
    } catch (error) {
      return failure(error)
    }
  }),
}
