import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import {
  allowedPrivacy,
  body,
  failure,
  isAnonymousUser,
  ok,
  optionalString,
  userId,
} from "../_shared/mosaic.ts";

type RequestBody = { displayName?: string; privacy?: string };

const challengeColumns =
  "id,name,group_name,purpose,goal,start_at,reveal_at,revealed_at,status,schedule_revision,featured_recap_export_id,invitation_code,is_showcase,camera_roll_enabled";

async function stableUUID(seed: string): Promise<string> {
  const digest = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(seed)),
  ).slice(0, 16);
  digest[6] = (digest[6] & 0x0f) | 0x50;
  digest[8] = (digest[8] & 0x3f) | 0x80;
  const hex = [...digest].map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${
    hex.slice(16, 20)
  }-${hex.slice(20)}`;
}

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      const uid = userId(ctx);
      const input = request.method === "POST"
        ? await body<RequestBody>(request)
        : {};
      const displayName =
        optionalString(input.displayName, "displayName", 60) ??
          "Guest participant";
      const privacy = input.privacy && allowedPrivacy.has(input.privacy)
        ? input.privacy
        : "first_name";
      const admin = ctx.supabaseAdmin;

      const { error: profileError } = await admin.from("profiles").upsert({
        user_id: uid,
        display_name: displayName,
        is_demo: isAnonymousUser(ctx),
        updated_at: new Date().toISOString(),
      }, { onConflict: "user_id" });
      if (profileError) throw profileError;

      const { data: showcase, error: showcaseError } = await admin
        .from("challenges")
        .select(challengeColumns)
        .eq("is_showcase", true)
        .single();
      if (showcaseError) throw showcaseError;

      const { error: showcaseMemberError } = await admin.from(
        "challenge_members",
      ).upsert({
        challenge_id: showcase.id,
        user_id: uid,
        role: "participant",
        display_name: displayName,
        privacy,
      }, { onConflict: "challenge_id,user_id" });
      if (showcaseMemberError) throw showcaseMemberError;

      // Every installation gets one deterministic synthetic workspace. It is
      // safe for public judging, survives retries, and remains attached to the
      // same UUID if the guest later links Sign in with Apple.
      const organizationID = await stableUUID(
        `mosaic:judge-organization:${uid}`,
      );
      const sandboxID = await stableUUID(`mosaic:judge-sandbox:${uid}`);
      const invitationCode = `M${uid.replaceAll("-", "").slice(0, 7)}`
        .toUpperCase();

      const { error: organizationError } = await admin.from("organizations")
        .upsert({
          id: organizationID,
          name: "Judge Sandbox",
          created_by: uid,
        }, { onConflict: "id" });
      if (organizationError) throw organizationError;

      const { error: organizationMemberError } = await admin.from(
        "organization_members",
      ).upsert({
        organization_id: organizationID,
        user_id: uid,
        role: "owner",
      }, { onConflict: "organization_id,user_id" });
      if (organizationMemberError) throw organizationMemberError;

      const { error: billingError } = await admin.from("billing_accounts")
        .upsert({
          organization_id: organizationID,
          owner_user_id: uid,
          revenuecat_customer_id: `demo:${uid}`,
        }, { onConflict: "organization_id" });
      if (billingError) throw billingError;

      let { data: sandbox, error: sandboxLookupError } = await admin
        .from("challenges")
        .select(challengeColumns)
        .eq("id", sandboxID)
        .maybeSingle();
      if (sandboxLookupError) throw sandboxLookupError;

      if (!sandbox) {
        const startAt = new Date();
        const revealAt = new Date(startAt.getTime() + 48 * 60 * 60 * 1000);
        const { data: created, error: createError } = await admin.from(
          "challenges",
        ).insert({
          id: sandboxID,
          organizer_id: uid,
          organization_id: organizationID,
          created_by: uid,
          name: "Judge Sandbox",
          group_name: "Reverie Hacks Judges",
          purpose:
            "A private synthetic space for exploring Mosaic's complete organizer journey.",
          goal: 12,
          start_at: startAt.toISOString(),
          reveal_at: revealAt.toISOString(),
          invitation_code: invitationCode,
          is_showcase: false,
          camera_roll_enabled: true,
        }).select(challengeColumns).single();
        if (createError) {
          // A concurrent retry may have won the deterministic insert.
          const retry = await admin.from("challenges").select(challengeColumns)
            .eq("id", sandboxID).single();
          if (retry.error) throw createError;
          sandbox = retry.data;
        } else {
          sandbox = created;
        }
      }

      const { error: organizerMemberError } = await admin.from(
        "challenge_members",
      ).upsert({
        challenge_id: sandboxID,
        user_id: uid,
        role: "organizer",
        display_name: displayName,
        privacy,
      }, { onConflict: "challenge_id,user_id" });
      if (organizerMemberError) throw organizerMemberError;

      const { data: templates, error: templatesError } = await admin
        .from("missions")
        .select(
          "title,detail,category,minutes,effort,accepted_evidence,sort_order",
        )
        .eq("challenge_id", showcase.id)
        .order("sort_order");
      if (templatesError) throw templatesError;

      const missionRows = await Promise.all(
        templates.map(async (mission: Record<string, unknown>) => ({
          ...mission,
          id: await stableUUID(
            `mosaic:judge-mission:${sandboxID}:${mission.sort_order}`,
          ),
          challenge_id: sandboxID,
        })),
      );
      const { data: missions, error: missionError } = await admin.from(
        "missions",
      ).upsert(missionRows, { onConflict: "id" }).select("id,sort_order")
        .order("sort_order");
      if (missionError) throw missionError;

      const pendingRows = await Promise.all(
        missions.slice(0, 3).map(
          async (mission: { id: string }, index: number) => ({
            id: await stableUUID(
              `mosaic:judge-pending:${sandboxID}:${index}`,
            ),
            challenge_id: sandboxID,
            mission_id: mission.id,
            emotion: ["hopeful", "joyful", "caring"][index],
            evidence_method: ["photo", "video", "organizer"][index],
            status: "pending_review",
          }),
        ),
      );
      const { error: pendingError } = await admin.from("contributions").upsert(
        pendingRows,
        { onConflict: "id", ignoreDuplicates: true },
      );
      if (pendingError) throw pendingError;

      const { error: ownerError } = await admin.from("contribution_owners")
        .upsert(
          pendingRows.map((row) => ({
            contribution_id: row.id,
            participant_id: uid,
          })),
          { onConflict: "contribution_id" },
        );
      if (ownerError) throw ownerError;

      const { error: evidenceError } = await admin.from("evidence_submissions")
        .upsert(
          pendingRows.map((row, index) => ({
            contribution_id: row.id,
            reflection_text: index === 2
              ? "Organizer confirmation requested for this synthetic act."
              : null,
          })),
          { onConflict: "contribution_id" },
        );
      if (evidenceError) throw evidenceError;

      return ok({ showcase, sandbox });
    } catch (error) {
      return failure(error);
    }
  }),
};
