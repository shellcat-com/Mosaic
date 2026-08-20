export type FunctionContext = {
  supabase: any;
  supabaseAdmin: any;
  userClaims?: { id?: string; sub?: string; is_anonymous?: boolean } | null;
};

export class HttpError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

export function userId(ctx: FunctionContext): string {
  const id = ctx.userClaims?.id ?? ctx.userClaims?.sub;
  if (!id) throw new HttpError(401, "A signed-in user is required");
  return id;
}

export function isAnonymousUser(ctx: FunctionContext): boolean {
  return ctx.userClaims?.is_anonymous === true;
}

export function requirePermanentAccount(ctx: FunctionContext): string {
  const id = userId(ctx);
  if (isAnonymousUser(ctx)) {
    throw new HttpError(403, "Sign in with Apple is required");
  }
  return id;
}

export async function assertOrganizationRole(
  ctx: FunctionContext,
  organizationId: string,
  roles: Array<"owner" | "admin" | "reviewer">,
) {
  const uid = requirePermanentAccount(ctx);
  const { data, error } = await ctx.supabaseAdmin.from("organization_members")
    .select("organization_id,user_id,role")
    .eq("organization_id", organizationId)
    .eq("user_id", uid)
    .maybeSingle();
  if (error) throw new HttpError(500, error.message);
  if (!data || !roles.includes(data.role)) {
    throw new HttpError(403, "Organization permission required");
  }
  return data;
}

export async function body<T>(request: Request): Promise<T> {
  if (request.method !== "POST") throw new HttpError(405, "POST required");
  try {
    return await request.json() as T;
  } catch {
    throw new HttpError(400, "Invalid JSON body");
  }
}

export function requiredString(
  value: unknown,
  field: string,
  max = 500,
): string {
  if (typeof value !== "string") {
    throw new HttpError(400, `${field} is required`);
  }
  const normalized = value.trim();
  if (!normalized || normalized.length > max) {
    throw new HttpError(400, `${field} is invalid`);
  }
  return normalized;
}

export function optionalString(
  value: unknown,
  field: string,
  max = 2000,
): string | null {
  if (value == null || value === "") return null;
  if (typeof value !== "string" || value.length > max) {
    throw new HttpError(400, `${field} is invalid`);
  }
  return value.trim();
}

export function requiredUUID(value: unknown, field: string): string {
  const text = requiredString(value, field, 36);
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(text)
  ) {
    throw new HttpError(400, `${field} must be a UUID`);
  }
  return text;
}

export async function assertMember(ctx: FunctionContext, challengeId: string) {
  const uid = userId(ctx);
  const { data, error } = await ctx.supabase
    .from("challenge_members")
    .select("challenge_id,user_id,role")
    .eq("challenge_id", challengeId)
    .eq("user_id", uid)
    .maybeSingle();
  if (error) throw new HttpError(500, error.message);
  if (!data) throw new HttpError(403, "Challenge membership required");
  return data;
}

export async function assertOrganizer(
  ctx: FunctionContext,
  challengeId: string,
) {
  const membership = await assertMember(ctx, challengeId);
  if (membership.role !== "organizer") {
    throw new HttpError(403, "Organizer access required");
  }
  return membership;
}

export function ok(payload: unknown, status = 200): Response {
  return Response.json(payload, { status });
}

export function failure(error: unknown): Response {
  if (error instanceof HttpError) {
    return Response.json({ error: error.message }, { status: error.status });
  }
  console.error(error);
  return Response.json({ error: "Unexpected server error" }, { status: 500 });
}

export const allowedEvidence = new Set([
  "reflection",
  "photo",
  "video",
  "receipt",
  "organizer",
]);
export const allowedEmotions = new Set(["hopeful", "joyful", "caring", "calm"]);
export const allowedPrivacy = new Set(["first_name", "anonymous", "quiet"]);

export function extensionForMime(mimeType: string): string {
  switch (mimeType) {
    case "image/jpeg":
      return "jpg";
    case "image/png":
      return "png";
    case "video/quicktime":
      return "mov";
    case "video/mp4":
      return "mp4";
    default:
      throw new HttpError(400, "Unsupported media type");
  }
}
