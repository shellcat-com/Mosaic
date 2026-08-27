# Mosaic App Store web checklist

## Public URLs

| Field | URL |
| --- | --- |
| Marketing | https://shellcat-com.github.io/Mosaic/ |
| Support | https://shellcat-com.github.io/Mosaic/support/ |
| Privacy Policy | https://shellcat-com.github.io/Mosaic/privacy/ |
| Account deletion | https://shellcat-com.github.io/Mosaic/account-deletion/ |
| Terms | https://shellcat-com.github.io/Mosaic/terms/ |
| Community Guidelines | https://shellcat-com.github.io/Mosaic/community-guidelines/ |

## Final audit

- Confirm the durable developer name and contact email.
- Confirm App Store privacy answers match [`APP_STORE_DISCLOSURES.md`](APP_STORE_DISCLOSURES.md) and `PrivacyInfo.xcprivacy`.
- Test Sign in with Apple first authorization, returning authorization, required display-name creation, sign out, and deletion.
- Confirm Camera and Add Photos are the only runtime permission prompts.
- Test report quarantine, block filtering, photographer deletion, and creator deletion against the production RLS deployment.
- Verify that no anonymous Auth provider, widget, Live Activity, notification, calendar, microphone, or Photo Library read capability appears in the archived build.
- Verify the processed build's Mosaic Plus monthly/annual subscriptions and one-event Event Pass exactly match the live RevenueCat offering, App Store products, localized terms, restore behavior, and submitted IAP metadata.
- Verify the support, privacy, terms, community-guidelines, and deletion pages without authentication.
- Re-check age rating and school/youth language with qualified counsel for the intended release countries.
- Complete export compliance for Mosaic's AES-GCM artwork-reveal package; the app archive declares `ITSAppUsesNonExemptEncryption = YES`.
- Replace both invitation placeholders in [`TESTFLIGHT_REVIEW_NOTES.md`](TESTFLIGHT_REVIEW_NOTES.md) with hosted, review-safe active and revealed Mosaics.
- Upload the seven opaque 1320×2868 JPEGs from `design/app-store-screenshots/6.9-inch/`.

The current section-by-section result is recorded in [`APP_STORE_REVIEW_AUDIT.md`](APP_STORE_REVIEW_AUDIT.md).

The legal pages describe the v3 product but are not a substitute for legal advice.
