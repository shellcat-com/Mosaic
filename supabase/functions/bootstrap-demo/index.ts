import "@supabase/functions-js/edge-runtime.d.ts"
import { withSupabase } from "@supabase/server"
import { allowedPrivacy, body, failure, ok, optionalString, userId } from "../_shared/mosaic.ts"

type RequestBody = { displayName?: string; privacy?: string }

export default {
  fetch: withSupabase({ auth: "user" }, async (request, ctx) => {
    try {
      const uid = userId(ctx)
      const input = request.method === "POST" ? await body<RequestBody>(request) : {}
      const displayName = optionalString(input.displayName, "displayName", 60) ?? "Guest participant"
      const privacy = input.privacy && allowedPrivacy.has(input.privacy) ? input.privacy : "first_name"
      const admin = ctx.supabaseAdmin

      const { error: profileError } = await admin.from("profiles").upsert({
        user_id: uid,
        display_name: displayName,
        is_demo: true,
        updated_at: new Date().toISOString(),
      }, { onConflict: "user_id" })
      if (profileError) throw profileError

      const { data: showcase, error: showcaseError } = await admin
        .from("challenges")
        .select("id,name,purpose,goal,reveal_at,status,invitation_code,is_showcase")
        .eq("is_showcase", true)
        .single()
      if (showcaseError) throw showcaseError

      const { error: showcaseMemberError } = await admin.from("challenge_members").upsert({
        challenge_id: showcase.id,
        user_id: uid,
        role: "participant",
        display_name: displayName,
        privacy,
      }, { onConflict: "challenge_id,user_id" })
      if (showcaseMemberError) throw showcaseMemberError

      let { data: sandbox, error: sandboxLookupError } = await admin
        .from("challenges")
        .select("id,name,purpose,goal,reveal_at,status,invitation_code,is_showcase")
        .eq("organizer_id", uid)
        .eq("is_showcase", false)
        .maybeSingle()
      if (sandboxLookupError) throw sandboxLookupError

      let createdSandbox = false
      if (!sandbox) {
        const invitationCode = `M${uid.replaceAll("-", "").slice(0, 7)}`.toUpperCase()
        const revealAt = new Date(Date.now() + 48 * 60 * 60 * 1000).toISOString()
        const { data: created, error: createError } = await admin.from("challenges").insert({
          organizer_id: uid,
          name: "Judge Sandbox",
          purpose: "A private space to explore Mosaic’s complete organizer journey.",
          goal: 12,
          reveal_at: revealAt,
          invitation_code: invitationCode,
          is_showcase: false,
        }).select("id,name,purpose,goal,reveal_at,status,invitation_code,is_showcase").single()
        if (createError) throw createError
        sandbox = created
        createdSandbox = true
      }

      const { error: organizerMemberError } = await admin.from("challenge_members").upsert({
        challenge_id: sandbox.id,
        user_id: uid,
        role: "organizer",
        display_name: displayName,
        privacy,
      }, { onConflict: "challenge_id,user_id" })
      if (organizerMemberError) throw organizerMemberError

      if (createdSandbox) {
        const { data: templates, error: templatesError } = await admin
          .from("missions")
          .select("title,detail,category,minutes,effort,accepted_evidence,sort_order")
          .eq("challenge_id", showcase.id)
          .order("sort_order")
        if (templatesError) throw templatesError
        const { data: missions, error: missionInsertError } = await admin.from("missions")
          .insert(templates.map((mission: Record<string, unknown>) => ({ ...mission, challenge_id: sandbox.id })))
          .select("id,sort_order")
        if (missionInsertError) throw missionInsertError

        const pending = missions.slice(0, 3).map((mission: { id: string }, index: number) => ({
          id: crypto.randomUUID(),
          challenge_id: sandbox.id,
          mission_id: mission.id,
          emotion: ["hopeful", "joyful", "caring"][index],
          evidence_method: ["photo", "video", "organizer"][index],
          status: "pending_review",
        }))
        const { data: pendingRows, error: pendingError } = await admin.from("contributions")
          .insert(pending).select("id")
        if (pendingError) throw pendingError
        const { error: ownerError } = await admin.from("contribution_owners").insert(
          pendingRows.map((row: { id: string }) => ({ contribution_id: row.id, participant_id: uid }))
        )
        if (ownerError) throw ownerError
        const { error: evidenceError } = await admin.from("evidence_submissions").insert(
          pendingRows.map((row: { id: string }, index: number) => ({
            contribution_id: row.id,
            reflection_text: index === 2 ? "Organizer confirmation requested for this act." : null,
          }))
        )
        if (evidenceError) throw evidenceError
      }

      return ok({ showcase, sandbox })
    } catch (error) {
      return failure(error)
    }
  }),
}
