import "@supabase/functions-js/edge-runtime.d.ts"
import { withSupabase } from "@supabase/server"
import {
  allowedEmotions, allowedEvidence, assertMember, body, extensionForMime, failure, HttpError,
  ok, optionalString, requiredString, requiredUUID, userId,
} from "../_shared/mosaic.ts"

type RequestBody = {
  contributionId: string
  challengeId: string
  missionId: string
  emotion: string
  evidenceMethod: string
  reflection?: string
  mimeType?: string
  fileSize?: number
  durationSeconds?: number
}

export default {
  fetch: withSupabase({ auth: "user" }, async (request, ctx) => {
    try {
      const uid = userId(ctx)
      const input = await body<RequestBody>(request)
      const contributionId = requiredUUID(input.contributionId, "contributionId")
      const challengeId = requiredUUID(input.challengeId, "challengeId")
      const missionId = requiredUUID(input.missionId, "missionId")
      const emotion = requiredString(input.emotion, "emotion", 20)
      const method = requiredString(input.evidenceMethod, "evidenceMethod", 20)
      if (!allowedEmotions.has(emotion)) throw new HttpError(400, "emotion is invalid")
      if (!allowedEvidence.has(method)) throw new HttpError(400, "evidence method is unavailable")
      await assertMember(ctx, challengeId)

      const { data: challenge, error: challengeError } = await ctx.supabase
        .from("challenges").select("is_showcase,status").eq("id", challengeId).single()
      if (challengeError) throw challengeError
      if (challenge.is_showcase) throw new HttpError(403, "The showcase is read-only; use the organizer sandbox")
      if (challenge.status !== "active") throw new HttpError(409, "This challenge is no longer accepting evidence")

      const { data: mission, error: missionError } = await ctx.supabase
        .from("missions").select("accepted_evidence").eq("id", missionId).eq("challenge_id", challengeId).single()
      if (missionError) throw missionError
      if (!mission.accepted_evidence.includes(method)) throw new HttpError(400, "Mission does not accept this evidence")

      const reflection = optionalString(input.reflection, "reflection")
      let mediaPath: string | null = null
      let upload: Record<string, unknown> | null = null

      if (["photo", "video", "receipt"].includes(method)) {
        const mimeType = requiredString(input.mimeType, "mimeType", 80)
        const fileSize = input.fileSize
        if (!Number.isInteger(fileSize) || Number(fileSize) <= 0) throw new HttpError(400, "fileSize is invalid")
        const isImage = mimeType === "image/jpeg" || mimeType === "image/png"
        const isVideo = mimeType === "video/quicktime" || mimeType === "video/mp4"
        if ((method === "video" && !isVideo) || (method !== "video" && !isImage)) {
          throw new HttpError(400, "Media type does not match the evidence method")
        }
        if (method === "video") {
          if (Number(fileSize) > 26_214_400) throw new HttpError(413, "Video must be 25 MB or smaller")
          if (typeof input.durationSeconds !== "number" || input.durationSeconds <= 0 || input.durationSeconds > 10) {
            throw new HttpError(400, "Video must be 10 seconds or shorter")
          }
        } else if (Number(fileSize) > 10_485_760) {
          throw new HttpError(413, "Image must be 10 MB or smaller")
        }
        mediaPath = `${challengeId}/${uid}/${contributionId}.${extensionForMime(mimeType)}`
      } else if (method === "reflection" && !reflection) {
        throw new HttpError(400, "Reflection text is required")
      }

      const admin = ctx.supabaseAdmin
      const { data: existingOwner, error: ownerLookupError } = await admin.from("contribution_owners")
        .select("participant_id").eq("contribution_id", contributionId).maybeSingle()
      if (ownerLookupError) throw ownerLookupError
      if (existingOwner && existingOwner.participant_id !== uid) throw new HttpError(409, "Contribution ID is already in use")

      const { error: contributionError } = await admin.from("contributions").upsert({
        id: contributionId,
        challenge_id: challengeId,
        mission_id: missionId,
        emotion,
        evidence_method: method,
        status: "draft",
        updated_at: new Date().toISOString(),
      }, { onConflict: "id" })
      if (contributionError) throw contributionError

      const { error: ownerError } = await admin.from("contribution_owners").upsert({
        contribution_id: contributionId,
        participant_id: uid,
      }, { onConflict: "contribution_id" })
      if (ownerError) throw ownerError

      const { error: evidenceError } = await admin.from("evidence_submissions").upsert({
        contribution_id: contributionId,
        reflection_text: reflection,
        media_path: mediaPath,
        mime_type: input.mimeType ?? null,
        file_size: input.fileSize ?? null,
        duration_seconds: input.durationSeconds ?? null,
      }, { onConflict: "contribution_id" })
      if (evidenceError) throw evidenceError

      if (mediaPath) {
        const { data: signed, error: signedError } = await admin.storage
          .from("evidence-private").createSignedUploadUrl(mediaPath, { upsert: true })
        if (signedError) throw signedError
        upload = { path: mediaPath, token: signed.token, signedUrl: signed.signedUrl }
      }

      return ok({ contributionId, upload })
    } catch (error) {
      return failure(error)
    }
  }),
}
