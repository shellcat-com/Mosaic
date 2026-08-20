# Notifications and Live Activities

Mosaic schedules predictable countdown reminders on-device. APNs is reserved for essential state changes: a moved reveal, an unscheduled early reveal, recap readiness, and starting an opted-in Live Activity 30 minutes before reveal. Delivery is best-effort and must not be described as guaranteed.

## Apple configuration

Use the same paid Apple Developer team for the app and `MosaicWidgets` targets. Enable Push Notifications, App Groups, and Live Activities. Replace the sample App Group identifier in `project.yml` and both entitlement files if the production bundle identifier differs.

Create an APNs signing key and configure these Supabase Edge Function secrets without committing their values:

```sh
supabase secrets set \
  APNS_KEY_ID='YOUR_KEY_ID' \
  APNS_TEAM_ID='YOUR_TEAM_ID' \
  APNS_PRIVATE_KEY='-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----' \
  APNS_BUNDLE_ID='com.biswaskhatiwada.mosaicapp' \
  MOSAIC_NOTIFICATION_DISPATCH_SECRET='A_LONG_RANDOM_VALUE'
```

Deploy the authenticated registration/preferences functions normally. The dispatcher has JWT verification disabled because it is invoked by a scheduler, but it requires `Authorization: Bearer <MOSAIC_NOTIFICATION_DISPATCH_SECRET>` and never accepts a client service-role key.

```sh
supabase functions deploy update-event-preferences
supabase functions deploy register-notification-token
supabase functions deploy dispatch-event-notifications --no-verify-jwt
```

## Dispatch scheduling

The database cron enqueues due Live Activities and event triggers enqueue essential changes idempotently. Invoke `dispatch-event-notifications` once per minute from a trusted scheduler. For a Supabase-hosted project, store the project URL and dispatch secret in Vault, then use `pg_cron` with `pg_net` to POST to the function. Keep those values out of migrations and source control.

The dispatcher claims at most 50 pending deliveries, uses each token's sandbox/production environment, disables APNs tokens that return HTTP 410, and records the outcome in a service-only delivery table. Re-running it cannot recreate a logical notification because queue rows have deterministic deduplication keys.

## Privacy boundaries

Notifications and Live Activities contain only the challenge name, timing, counts, state, and a deep link. The App Group cache contains safe challenge summaries and a rendered final-mosaic thumbnail. Evidence files, private memories, participant identities, notes, and raw media are never copied into notifications or widget storage.
