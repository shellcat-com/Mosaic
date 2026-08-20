# Security

## Demo threat model

Mosaic's public demo contains synthetic data only. The iOS app receives a Supabase publishable key and an anonymous user session; neither grants privileged database access. All exposed tables use row-level security, and client access is limited to the minimum explicit grants.

Identity and consent live in `contribution_owners`, evidence lives in `evidence_submissions`, and approved stories live in `memories`. Public mosaic reads use only the abstract `contributions` table. Private Storage buckets are accessed with short-lived signed URLs after an authenticated membership or organizer check.

Privileged lifecycle mutations are performed by authenticated Edge Functions. Each function validates the caller before its narrow service-level write. Contribution IDs and atomic placement make retries idempotent. Realtime carries only sanitized invalidation messages; clients refetch canonical, RLS-filtered state.

## Secrets

Safe to publish:

- Supabase project URL.
- Supabase publishable key.
- Synthetic challenge IDs and invite codes.

Never commit:

- Supabase secret or service-role keys.
- Database connection strings or passwords.
- Personal access tokens, CLI tokens, or Apple credentials.
- Real participant evidence or personal data.

Use `Config/Local.xcconfig` or environment variables for contributor overrides. The dedicated hosted demo project should be rotated or retired after judging.

## Reporting

Please report a vulnerability privately to the repository owner before publishing details. Include the affected component, reproduction steps, impact, and a suggested fix when possible. Do not upload real personal data while testing this hackathon demo.
