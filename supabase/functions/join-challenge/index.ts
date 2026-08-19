import "@supabase/functions-js/edge-runtime.d.ts"
import { withSupabase } from "@supabase/server"
import { allowedPrivacy, body, failure, HttpError, ok, requiredString, userId } from "../_shared/mosaic.ts"

type RequestBody = { code: string; displayName: string; privacy: string }

export default {
  fetch: withSupabase({ auth: "user" }, async (request, ctx) => {
    try {
      const uid = userId(ctx)
      const input = await body<RequestBody>(request)
      const code = requiredString(input.code, "code", 12).toUpperCase()
      const displayName = requiredString(input.displayName, "displayName", 60)
      if (!allowedPrivacy.has(input.privacy)) throw new HttpError(400, "privacy is invalid")

      const { data: challenge, error: lookupError } = await ctx.supabaseAdmin
        .from("challenges")
        .select("id,name,purpose,goal,reveal_at,status,invitation_code,is_showcase")
        .eq("invitation_code", code)
        .maybeSingle()
      if (lookupError) throw lookupError
      if (!challenge) throw new HttpError(404, "Challenge code not found")

      const { error: memberError } = await ctx.supabaseAdmin.from("challenge_members").upsert({
        challenge_id: challenge.id,
        user_id: uid,
        role: "participant",
        display_name: displayName,
        privacy: input.privacy,
      }, { onConflict: "challenge_id,user_id" })
      if (memberError) throw memberError

      const { error: profileError } = await ctx.supabaseAdmin.from("profiles").upsert({
        user_id: uid,
        display_name: displayName,
        is_demo: true,
        updated_at: new Date().toISOString(),
      }, { onConflict: "user_id" })
      if (profileError) throw profileError

      return ok({ challenge })
    } catch (error) {
      return failure(error)
    }
  }),
}
