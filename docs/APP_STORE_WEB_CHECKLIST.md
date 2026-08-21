# Mosaic App Store web checklist

This document maps the public Mosaic website to the URL fields and policy
surfaces used for an iOS release. Review the legal text against the final
production build, data practices, products, developer identity, and supported
countries before submitting.

## Public URLs

| App Store Connect field or review need | Mosaic URL | Status |
| --- | --- | --- |
| Marketing URL | https://shellcat-com.github.io/Mosaic/ | Ready |
| Support URL | https://shellcat-com.github.io/Mosaic/support/ | Ready |
| Privacy Policy URL | https://shellcat-com.github.io/Mosaic/privacy/ | Ready |
| User Privacy Choices URL | https://shellcat-com.github.io/Mosaic/account-deletion/ | Ready |
| Terms of Use URL | https://shellcat-com.github.io/Mosaic/terms/ | Ready |
| Community Guidelines / UGC safety | https://shellcat-com.github.io/Mosaic/community-guidelines/ | Ready |

Apple requires a Privacy Policy URL for iOS apps. App Review also expects the
app and its Support URL to provide an easy way to contact the developer. Apps
that create accounts must let users initiate account deletion inside the app.
Mosaic exposes deletion in **You → Account & privacy → Delete account** and
publishes the supporting explanation above.

Official references:

- https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
- https://developer.apple.com/support/offering-account-deletion-in-your-app/
- https://developer.apple.com/app-store/review/guidelines/

## Final production audit before submission

- Confirm the developer/seller identity and support email are appropriate for
  public release. Replace the current university email if a durable product
  support address is available.
- Confirm the Privacy Policy matches the exact production configuration for
  Supabase, RevenueCat, Sign in with Apple, notifications, media storage, and
  any analytics or crash-reporting SDK added later.
- Complete App Store Connect privacy nutrition-label answers for every data
  type collected by Mosaic or an integrated third party.
- Verify the in-app Privacy and Terms links open the published pages.
- Exercise account deletion for a guest, a permanent participant, a normal
  organizer, and a sole workspace owner. Confirm associated user-generated
  content is handled as described.
- Verify Sign in with Apple tokens are revoked when a linked account is deleted.
- Confirm Restore Purchases, subscription management, price/renewal copy, and
  RevenueCat entitlement synchronization in the App Store sandbox.
- Confirm the Support URL loads without authentication and the email link works.
- Verify community reporting and organizer moderation behavior for user-created
  text, photos, videos, and invitations.
- Re-check the age rating and the policy language if Mosaic will be used by
  schools or participants under the age of majority.
- Ask qualified counsel to review the production Privacy Policy and Terms for
  the intended countries. These drafts describe the product but are not a
  substitute for legal advice.

## Site deployment checks

- GitHub Pages deploys `site/` from `.github/workflows/pages.yml` on pushes to
  `main` that change the site or its workflow.
- The site includes a canonical URL, social sharing image, sitemap, robots file,
  touch icon, responsive navigation, reduced-motion support, semantic headings,
  and a custom not-found page.
- Invitation links using `?join=CODE` keep the existing `mosaic://join/CODE`
  handoff.
