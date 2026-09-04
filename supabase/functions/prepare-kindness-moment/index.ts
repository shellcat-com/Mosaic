import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import {
  assertMember,
  body,
  extensionForMime,
  failure,
  HttpError,
  ok,
  optionalString,
  requiredString,
  requiredUUID,
  userId,
} from "../_shared/mosaic.ts";

type RequestBody = {
  contributionId: string;
  challengeId: string;
  missionId: string;
  mediaKind: "photo" | "video" | "note";
  mimeType?: string;
  fileSize?: number;
  durationSeconds?: number;
  caption?: string;
  exportConsent?: boolean;
};

const looks = new Set(["sunwashed", "garden", "afterglow"]);

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      const uid = userId(ctx);
      const input = await body<RequestBody>(request);
      const contributionId = requiredUUID(
        input.contributionId,
        "contributionId",
      );
      const challengeId = requiredUUID(input.challengeId, "challengeId");
      const missionId = requiredUUID(input.missionId, "missionId");
      const mediaKind = requiredString(input.mediaKind, "mediaKind", 12);
      if (!new Set(["photo", "video", "note"]).has(mediaKind)) {
        throw new HttpError(400, "mediaKind is invalid");
      }
      await assertMember(ctx, challengeId);

      const admin = ctx.supabaseAdmin;
      const { data: challenge, error: challengeError } = await admin.from(
        "challenges",
      )
        .select("id,status,reveal_at,experience_version,film_look_id,goal")
        .eq("id", challengeId).single();
      if (challengeError) throw challengeError;
      if (challenge.experience_version !== 2) {
        throw new HttpError(
          409,
          "This group uses the legacy contribution flow",
        );
      }
      if (
        challenge.status !== "active" ||
        new Date(challenge.reveal_at) <= new Date()
      ) {
        throw new HttpError(409, "This group is no longer accepting moments");
      }
      if (!looks.has(challenge.film_look_id)) {
        throw new HttpError(409, "The group film look is invalid");
      }

      const { data: mission, error: missionError } = await admin.from(
        "missions",
      )
        .select("id,category").eq("id", missionId).eq(
          "challenge_id",
          challengeId,
        ).single();
      if (missionError) throw missionError;

      const caption = optionalString(input.caption, "caption", 280);
      let mimeType: string | null = null;
      let mediaPath: string | null = null;
      let upload: Record<string, unknown> | null = null;
      if (mediaKind !== "note") {
        mimeType = requiredString(input.mimeType, "mimeType", 80);
        const isImage = mimeType === "image/jpeg" || mimeType === "image/png";
        const isVideo = mimeType === "video/quicktime" ||
          mimeType === "video/mp4";
        if (
          (mediaKind === "photo" && !isImage) ||
          (mediaKind === "video" && !isVideo)
        ) {
          throw new HttpError(
            400,
            "Media type does not match the selected moment",
          );
        }
        if (!Number.isInteger(input.fileSize) || Number(input.fileSize) <= 0) {
          throw new HttpError(400, "fileSize is invalid");
        }
        if (mediaKind === "photo" && Number(input.fileSize) > 10_485_760) {
          throw new HttpError(413, "Photo must be 10 MB or smaller");
        }
        if (mediaKind === "video") {
          if (Number(input.fileSize) > 26_214_400) {
            throw new HttpError(413, "Video must be 25 MB or smaller");
          }
          if (
            typeof input.durationSeconds !== "number" ||
            input.durationSeconds <= 0 || input.durationSeconds > 10
          ) {
            throw new HttpError(400, "Video must be 10 seconds or shorter");
          }
        }
        mediaPath = `moments/${challengeId}/${uid}/${contributionId}.${
          extensionForMime(mimeType)
        }`;
      } else if (!caption) {
        throw new HttpError(400, "Write a note before sealing it");
      }

      const evidenceMethod = mediaKind === "note" ? "reflection" : mediaKind;
      const { data: existingOwner, error: ownerLookupError } = await admin.from(
        "contribution_owners",
      )
        .select("participant_id").eq("contribution_id", contributionId)
        .maybeSingle();
      if (ownerLookupError) throw ownerLookupError;
      if (existingOwner && existingOwner.participant_id !== uid) {
        throw new HttpError(409, "Contribution ID is already in use");
      }

      const { error: contributionError } = await admin.from("contributions")
        .upsert({
          id: contributionId,
          challenge_id: challengeId,
          mission_id: missionId,
          emotion: "caring",
          evidence_method: evidenceMethod,
          status: "draft",
          updated_at: new Date().toISOString(),
        }, { onConflict: "id" });
      if (contributionError) throw contributionError;

      const { error: ownerError } = await admin.from("contribution_owners")
        .upsert({
          contribution_id: contributionId,
          participant_id: uid,
          include_memory: true,
          show_identity: false,
          export_consent: Boolean(input.exportConsent),
        }, { onConflict: "contribution_id" });
      if (ownerError) throw ownerError;

      const { error: momentError } = await admin.from("shared_moments").upsert({
        id: contributionId,
        challenge_id: challengeId,
        creator_id: uid,
        contribution_id: contributionId,
        editorial_category: mission.category,
        note: caption,
        media_path: mediaPath,
        media_kind: mediaKind,
        media_mime_type: mimeType,
        duration_seconds: mediaKind === "video" ? input.durationSeconds : null,
        attribution: "anonymous",
        reveal_consent: true,
        export_consent: Boolean(input.exportConsent),
        film_look_id: challenge.film_look_id,
        lifecycle: "upload_pending",
      }, { onConflict: "id" });
      if (momentError) throw momentError;

      if (mediaPath) {
        const { data: signed, error: signedError } = await admin.storage.from(
          "recap-memories",
        )
          .createSignedUploadUrl(mediaPath, { upsert: true });
        if (signedError) throw signedError;
        upload = {
          path: mediaPath,
          token: signed.token,
          signedUrl: signed.signedUrl,
        };
      }

      return ok({
        contributionId,
        momentId: contributionId,
        filmLookId: challenge.film_look_id,
        upload,
      });
    } catch (error) {
      return failure(error);
    }
  }),
};
