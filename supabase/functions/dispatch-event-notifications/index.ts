import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

type Delivery = {
  id: string;
  challenge_id: string;
  user_id: string;
  kind: "schedule_changed" | "early_reveal" | "recap_ready" | "live_activity";
  schedule_revision: number;
  dedupe_key: string;
};

type Challenge = {
  id: string;
  name: string;
  goal: number;
  reveal_at: string;
  status: string;
};

type APNSResult = { ok: boolean; id?: string; status: number; reason?: string };

type LiveActivityToken = {
  token: string;
  environment: "sandbox" | "production";
  activity_id: string;
};

type Preference = {
  schedule_changes: boolean;
  reveal_now: boolean;
  recap_ready: boolean;
  live_activity: boolean;
};

export default {
  fetch: withSupabase<any>({ auth: "none" }, async (request, ctx) => {
    const expected = Deno.env.get("MOSAIC_NOTIFICATION_DISPATCH_SECRET");
    const provided = request.headers.get("authorization")?.replace(
      /^Bearer\s+/i,
      "",
    );
    if (!expected || provided !== expected) {
      return Response.json({ error: "Unauthorized" }, { status: 401 });
    }

    const configuration = apnsConfiguration();
    if (!configuration) {
      return Response.json({ error: "APNs is not configured" }, {
        status: 503,
      });
    }
    const jwt = await makeProviderToken(configuration);
    const admin = ctx.supabaseAdmin as any;

    const { data: pending, error: pendingError } = await admin
      .from("notification_deliveries")
      .select("id,challenge_id,user_id,kind,schedule_revision,dedupe_key")
      .eq("status", "pending")
      .order("created_at")
      .limit(50);
    if (pendingError) {
      return Response.json({ error: pendingError.message }, { status: 500 });
    }

    let sent = 0;
    let failed = 0;
    let skipped = 0;
    for (const delivery of (pending ?? []) as Delivery[]) {
      const { data: claimed } = await admin.from("notification_deliveries")
        .update({ status: "sending", attempted_at: new Date().toISOString() })
        .eq("id", delivery.id).eq("status", "pending").select("id")
        .maybeSingle();
      if (!claimed) continue;

      const [
        { data: challenge },
        { data: devices },
        { data: activities },
        contributionResult,
        { data: membership },
        { data: preference },
      ] = await Promise.all([
        admin.from("challenges")
          .select("id,name,goal,reveal_at,status").eq(
            "id",
            delivery.challenge_id,
          ).single(),
        admin.from("notification_devices")
          .select("id,token,environment").eq("user_id", delivery.user_id).is(
            "disabled_at",
            null,
          ),
        admin.from("live_activity_tokens")
          .select("token,environment,activity_id").eq(
            "user_id",
            delivery.user_id,
          )
          .eq("challenge_id", delivery.challenge_id).is("disabled_at", null),
        admin.from("contributions")
          .select("id", { count: "exact", head: true })
          .eq("challenge_id", delivery.challenge_id)
          .in("status", ["verified", "placed", "revealed", "self_attested"]),
        admin.from("challenge_members")
          .select("challenge_id").eq("challenge_id", delivery.challenge_id)
          .eq("user_id", delivery.user_id).maybeSingle(),
        admin.from("event_notification_preferences")
          .select("schedule_changes,reveal_now,recap_ready,live_activity")
          .eq("challenge_id", delivery.challenge_id)
          .eq("user_id", delivery.user_id).maybeSingle(),
      ]);

      if (
        !challenge || challenge.status === "archived" || !membership ||
        !preferenceAllows(delivery.kind, preference as Preference | null)
      ) {
        await admin.from("live_activity_tokens")
          .update({ disabled_at: new Date().toISOString() })
          .eq("challenge_id", delivery.challenge_id).eq(
            "user_id",
            delivery.user_id,
          );
        await finish(
          admin,
          delivery.id,
          "skipped",
          undefined,
          "Membership or opt-in is no longer active",
        );
        skipped += 1;
        continue;
      }

      if (!devices?.length && !activities?.length) {
        await finish(
          admin,
          delivery.id,
          "skipped",
          undefined,
          "No active notification destination",
        );
        skipped += 1;
        continue;
      }

      const message = notificationMessage(
        delivery.kind,
        challenge as Challenge,
      );
      const results: APNSResult[] = [];
      for (
        const device of delivery.kind === "live_activity" ? [] : (devices ?? [])
      ) {
        const payload = {
          aps: {
            alert: { title: message.title, body: message.body },
            sound: "default",
            "thread-id": `challenge.${delivery.challenge_id}`,
          },
          deep_link: `mosaic://${message.route}/${delivery.challenge_id}`,
        };
        const result = await sendAPNS(
          device.token,
          device.environment,
          configuration.bundleID,
          "alert",
          payload,
          jwt,
          delivery.dedupe_key,
        );
        results.push(result);
        if (result.status === 410) {
          await admin.from("notification_devices")
            .update({ disabled_at: new Date().toISOString() }).eq(
              "id",
              device.id,
            );
        }
      }

      const activityTokens = (activities ?? []) as LiveActivityToken[];
      if (delivery.kind === "live_activity") {
        for (
          const activity of activityTokens.filter((item) =>
            item.activity_id.startsWith("push-to-start:")
          )
        ) {
          results.push(
            await sendLiveActivityStart(
              activity.token,
              activity.environment,
              delivery,
              challenge as Challenge,
              contributionResult.count ?? 0,
              configuration,
              jwt,
            ),
          );
        }
      } else if (
        delivery.kind === "early_reveal" || delivery.kind === "recap_ready"
      ) {
        for (
          const activity of activityTokens.filter((item) =>
            !item.activity_id.startsWith("push-to-start:")
          )
        ) {
          const result = await sendLiveActivityUpdate(
            activity.token,
            activity.environment,
            delivery,
            challenge as Challenge,
            contributionResult.count ?? 0,
            configuration,
            jwt,
          );
          results.push(result);
          if (result.status === 410) {
            await admin.from("live_activity_tokens")
              .update({ disabled_at: new Date().toISOString() }).eq(
                "token",
                activity.token,
              );
          }
        }
      }

      if (!results.length) {
        await finish(
          admin,
          delivery.id,
          "skipped",
          undefined,
          "No compatible notification destination",
        );
        skipped += 1;
        continue;
      }
      const success = results.find((result) => result.ok);
      if (success) {
        await finish(admin, delivery.id, "sent", success.id);
        sent += 1;
      } else {
        const reason = results.map((result) =>
          `${result.status}:${result.reason ?? "unknown"}`
        ).join(", ");
        await finish(admin, delivery.id, "failed", undefined, reason);
        failed += 1;
      }
    }
    return Response.json({
      processed: sent + failed + skipped,
      sent,
      failed,
      skipped,
    });
  }),
};

function apnsConfiguration() {
  const keyID = Deno.env.get("APNS_KEY_ID");
  const teamID = Deno.env.get("APNS_TEAM_ID");
  const privateKey = Deno.env.get("APNS_PRIVATE_KEY");
  const bundleID = Deno.env.get("APNS_BUNDLE_ID") ?? "com.mosaic.kindness";
  if (!keyID || !teamID || !privateKey) return null;
  return { keyID, teamID, privateKey, bundleID };
}

async function makeProviderToken(
  configuration: NonNullable<ReturnType<typeof apnsConfiguration>>,
) {
  const header = base64url(
    JSON.stringify({ alg: "ES256", kid: configuration.keyID }),
  );
  const claims = base64url(
    JSON.stringify({
      iss: configuration.teamID,
      iat: Math.floor(Date.now() / 1000),
    }),
  );
  const unsigned = `${header}.${claims}`;
  const pem = configuration.privateKey.replaceAll("\\n", "\n");
  const der = Uint8Array.from(
    atob(
      pem.replace(
        /-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g,
        "",
      ),
    ),
    (character) => character.charCodeAt(0),
  );
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(unsigned),
  );
  return `${unsigned}.${base64url(new Uint8Array(signature))}`;
}

async function sendAPNS(
  token: string,
  environment: string,
  topic: string,
  pushType: "alert" | "liveactivity",
  payload: unknown,
  jwt: string,
  collapseID: string,
): Promise<APNSResult> {
  const host = environment === "production"
    ? "api.push.apple.com"
    : "api.sandbox.push.apple.com";
  const response = await fetch(`https://${host}/3/device/${token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": topic,
      "apns-push-type": pushType,
      "apns-priority": pushType === "alert" ? "10" : "5",
      "apns-collapse-id": collapseID.slice(0, 64),
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  const responseBody: Record<string, unknown> = response.ok
    ? {}
    : await response.json().catch(() => ({})) as Record<string, unknown>;
  return {
    ok: response.ok,
    id: response.headers.get("apns-id") ?? undefined,
    status: response.status,
    reason: typeof responseBody.reason === "string"
      ? responseBody.reason
      : undefined,
  };
}

async function sendLiveActivityUpdate(
  token: string,
  environment: "sandbox" | "production",
  delivery: Delivery,
  challenge: Challenge,
  contributionCount: number,
  configuration: NonNullable<ReturnType<typeof apnsConfiguration>>,
  jwt: string,
) {
  const recapReady = delivery.kind === "recap_ready";
  const unixNow = Math.floor(Date.now() / 1000);
  const referenceRevealDate = new Date(challenge.reveal_at).getTime() / 1000 -
    978307200;
  const payload = {
    aps: {
      timestamp: unixNow,
      event: recapReady ? "end" : "update",
      "dismissal-date": recapReady ? unixNow + 900 : undefined,
      "content-state": {
        contributionCount,
        goal: challenge.goal,
        revealAt: referenceRevealDate,
        phase: recapReady ? "completed" : "reveal",
        recapReady,
      },
    },
  };
  return await sendAPNS(
    token,
    environment,
    `${configuration.bundleID}.push-type.liveactivity`,
    "liveactivity",
    payload,
    jwt,
    delivery.dedupe_key,
  );
}

async function sendLiveActivityStart(
  token: string,
  environment: "sandbox" | "production",
  delivery: Delivery,
  challenge: Challenge,
  contributionCount: number,
  configuration: NonNullable<ReturnType<typeof apnsConfiguration>>,
  jwt: string,
) {
  const unixNow = Math.floor(Date.now() / 1000);
  const referenceRevealDate = new Date(challenge.reveal_at).getTime() / 1000 -
    978307200;
  const payload = {
    aps: {
      timestamp: unixNow,
      event: "start",
      "input-push-token": 1,
      alert: {
        title: "Reveal starting soon",
        body: `${challenge.name} is now on your Lock Screen.`,
      },
      "content-state": {
        contributionCount,
        goal: challenge.goal,
        revealAt: referenceRevealDate,
        phase: "active",
        recapReady: false,
      },
      "attributes-type": "MosaicActivityAttributes",
      attributes: {
        challengeID: challenge.id,
        challengeName: challenge.name,
      },
    },
  };
  return await sendAPNS(
    token,
    environment,
    `${configuration.bundleID}.push-type.liveactivity`,
    "liveactivity",
    payload,
    jwt,
    delivery.dedupe_key,
  );
}

function notificationMessage(kind: Delivery["kind"], challenge: Challenge) {
  const reveal = new Intl.DateTimeFormat("en", {
    dateStyle: "medium",
    timeStyle: "short",
  })
    .format(new Date(challenge.reveal_at));
  switch (kind) {
    case "schedule_changed":
      return {
        title: "Reveal time changed",
        body: `${challenge.name} now reveals ${reveal}.`,
        route: "challenge",
      };
    case "early_reveal":
      return {
        title: "The mosaic is ready",
        body: `The reveal for ${challenge.name} has begun.`,
        route: "reveal",
      };
    case "recap_ready":
      return {
        title: "Your Mosaic recap is ready",
        body: `Keep the story of ${challenge.name} close.`,
        route: "recap",
      };
    case "live_activity":
      return {
        title: "Follow the reveal live",
        body: `${challenge.name} is opening now.`,
        route: "reveal",
      };
  }
}

function preferenceAllows(
  kind: Delivery["kind"],
  preference: Preference | null,
): boolean {
  if (!preference) return false;
  switch (kind) {
    case "schedule_changed":
      return preference.schedule_changes;
    case "early_reveal":
      return preference.reveal_now;
    case "recap_ready":
      return preference.recap_ready;
    case "live_activity":
      return preference.live_activity;
  }
}

async function finish(
  admin: any,
  id: string,
  status: "sent" | "failed" | "skipped",
  providerID?: string,
  error?: string,
) {
  await admin.from("notification_deliveries").update({
    status,
    provider_id: providerID ?? null,
    error: error?.slice(0, 1000) ?? null,
    delivered_at: status === "sent" ? new Date().toISOString() : null,
  }).eq("id", id);
}

function base64url(value: string | Uint8Array): string {
  const bytes = typeof value === "string"
    ? new TextEncoder().encode(value)
    : value;
  let binary = "";
  bytes.forEach((byte) => binary += String.fromCharCode(byte));
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(
    /=+$/,
    "",
  );
}
