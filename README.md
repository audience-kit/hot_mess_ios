# Hot Mess (iOS)

Nightlife app for finding venues, events and friends nearby.

The app was originally written in 2017 against Swift 3/4 with storyboards,
`UITableViewController` subclasses and callback-based networking. It has been
reworked into SwiftUI with Swift 6 concurrency; this file describes the shape of
the result.

## Requirements

- Xcode 16 or later (the project uses file-system synchronized folders,
  `objectVersion = 77`)
- iOS 18 deployment target
- Swift 6 language mode with complete strict-concurrency checking

Dependencies resolve through Swift Package Manager on first open:

| Package | Used for |
| --- | --- |
| [facebook-ios-sdk](https://github.com/facebook/facebook-ios-sdk) | Login |
| [Kingfisher](https://github.com/onevcat/Kingfisher) | Remote image loading and caching |
| [AudienceKit](https://github.com/audience-kit/audience-kit) (`sdk/swift`) | Sign-in, session, GraphQL and branding against the AudienceKit API |
| [Stripe](https://github.com/stripe/stripe-ios-spm) (`StripePaymentSheet`) | Paying cover at Stripe venues |
| [Square In-App Payments](https://github.com/square/in-app-payments-ios) (`SquareInAppPaymentsSDK`) | Paying cover at Square venues |

The app runs on iPhone and iPad.

## Layout

```
HotMess/
  App/            SwiftUI entry point, routing, deep links
  Models/         Codable value types for every API payload
  Networking/     APIClient, typed endpoints, configuration, errors
  Services/       Session, keychain, location, realtime chat, logging
  DesignSystem/   Shared rows, images, load states, theme
  Features/       One folder per screen: a view plus its view model
Configurations/   Per-environment .xcconfig files
HotMessTests/     Swift Testing suites (offline)
HotMessUITests/   Launch smoke test
```

Source files are picked up from the folder tree automatically — adding a file
does not touch `project.pbxproj`.

## Architecture

`AppModel` is the composition root. It builds the configuration, the API client,
the session store and the location provider once, and is injected into the view
hierarchy with `.environment(...)`. Each screen owns a small `@Observable`,
`@MainActor` view model that exposes a single `LoadState` value, so loading,
empty and failure states are handled the same way everywhere.

- **AudienceKit.** Hot Mess is an AudienceKit audience. `AppModel` builds one
  `AudienceKitClient` from the configuration. `SessionStore` runs Facebook
  Login and hands the token to `AudienceKitClient.signIn`, which sends
  `POST /v1/token` with the audience host, the build's Facebook app ID and
  the device, then keeps the session JWT in the keychain. When the API ends
  the session (401), the SDK drops the token and `SessionStore` returns to
  the login screen. The Venues and People tabs read the audience over
  GraphQL, and `BrandStore` fetches `/v1/branding` and drives
  `Color.hotMessAccent` and the tint.
- **GraphQL.** Every other screen also goes through the audience's GraphQL
  endpoint on the SDK. `HotMessAPI` holds the documents: location reports and
  "Now" (`reportLocation`), the closest locale, venue, event and person
  detail, a locale's events, RSVPs (`rsvpEvent`), Pings (`sendPing`,
  `joinPing`, `leavePing`, `endPing`, and `myPing`/`friendPings` on Now,
  venues and events) and push registration (`registerDevice`, with the bundle
  ID and whether the build's `aps-environment` is the APNs sandbox).
- **Ping.** "I want to go out tonight": a Ping names tonight's events or
  venues in the user's locale (or none), reaches the user's friends (or
  friends of everyone in its circle) and clears at 5am. It's sent from the
  Now screen or "Ping here" on a venue or event, and friends answer with
  "I'm in", also from the `PING` push's `PING_JOIN` action. The documents alias fields to the snake_case keys the
  models decode, and failures map to `APIError`.
- **REST.** Only the version manifest (`POST /`) is still REST, because it's
  read before sign-in and isn't part of any audience. `APIClient` sends it
  through the SDK.
- **Models.** Every payload is a `Sendable`, `Codable` struct. Dates accept both
  the API's `yyyy-MM-dd'T'HH:mm:ss.SSSZ` format and plain ISO 8601, and IDs that
  Facebook sends as either a string or a number decode from both.
- **Concurrency.** Services are actors or `@MainActor` types; there are no
  shared mutable singletons behind the UI.

## Environments

`Debug`, `Staging` and `Release` build configurations map to the three
`.xcconfig` files in `Configurations/`, which set the API host, the
AudienceKit audience host (`AUDIENCE_HOST`) and optional ID, the Facebook app
ID, bundle suffix and APNs environment. Four shared schemes select between
them.

| Configuration | API | Facebook app |
| --- | --- | --- |
| Debug | `http://localhost:3000` | development (842337999153841) |
| Staging | `https://api-staging.audiencekit.com` | staging (1660272792277019) |
| Release | `https://api.audiencekit.com` | Hot Mess (1168782378316790) |

Release signs in with Hot Mess, a Consumer Facebook app, using classic Facebook
Login: `public_profile`, `email` and `user_friends` (friends who also use the app,
shown at the same venue). `user_friends` needs App Review on that app. The
AudienceKit platform app (713525445368431) is for businesses and isn't used here.

The API only accepts a Facebook app that belongs to the audience named by
`AUDIENCE_HOST`. `hotmess.admin.audiencekit.com` resolves by subdomain; switch
to `hotmess.social` once that domain is verified.

`FACEBOOK_CLIENT_TOKEN` is intentionally empty in each configuration: copy the
client token for each environment out of the Facebook app dashboard
(Settings → Advanced → Client token). The Facebook SDK reports an error at
runtime while it is blank.

## Cover

When a venue takes cover in the app (`coverCharge.payable`), its page, the
event that sets tonight's cover, and Now (at the venue) offer "Pay cover".
`CoverCheckout` calls `buyCover`, which says who takes the venue's cover
(`provider`):

- **Stripe**: Stripe's PaymentSheet on the venue's connected account
  (`STPAPIClient.shared.stripeAccount`; Connect direct charges) with the
  platform's publishable key, then `confirmCover`.
- **Square**: Square's In-App Payments SDK with the audience's
  `squareApplicationId`. The buyer picks Apple Pay (when Square can take it on
  the device) or Square's card form; either makes a payment token that
  `payCover` charges to the venue's Square location.

Then it shows the pass. Passes live under Me → Passes.

The pass's QR code is made on the phone every 30 seconds from the pass's
secret (`CoverPass`, the API's `app/services/cover_pass.rb`), so it works with
no signal; a sliding colour band shows staff it's live. Venue staff (anyone
`doorVenues` returns) get Me → Door, which scans passes with the camera and
calls `scanAdmission`.

Apple Pay uses `APPLE_PAY_MERCHANT_ID` (`merchant.social.hotmess`) from the
xcconfig files and the `in-app-payments` entitlement. Register that merchant
ID in the Apple Developer account and add an Apple Pay certificate for it on
Stripe; with the setting empty, both providers take cards only. Square venues
use the same merchant ID, which needs a payment processing certificate made
from Square's CSR (Square Developer Dashboard → the application → Apple Pay).
Apple encrypts each payment to one certificate per merchant ID, so if Stripe
and Square can't share it, give Square its own merchant ID.

## App icon

Each build configuration has one 1024×1024 universal icon with light, dark and
tinted appearances (`AppIcon` for Release, `AppIconStaging`, `AppIconDevelopment`
with a ribbon naming the build). They're rendered, not drawn by hand:
`Design/AppIcon/make_app_icon.py` recolours the original Hot Mess silhouette
(`Design/AppIcon/silhouette-mask.png`) with the AudienceKit `hot_mess` theme
(accent `#b8236f`, dark accent `#ff7ab6`, ink `#1a1519`). Edit the script and
run `python3 Design/AppIcon/make_app_icon.py` (needs Pillow) to change them.

## Tests

`HotMessTests` runs entirely offline: model decoding against inline fixtures,
endpoint URL construction, deep-link parsing, geometry and formatting. Run them
with any scheme, or:

```sh
xcodebuild test -scheme "HotMess Debug" -destination "platform=iOS Simulator,name=iPhone 17"
```

The previous suite authenticated against Facebook with a token committed to the
repository and then called the live API, so it could not run offline and could
not distinguish a regression from an outage.

## TestFlight

`Scripts/testflight.sh` archives the "HotMess Release" scheme, exports it for
App Store Connect with `Configurations/ExportOptions-AppStore.plist`, and
uploads it with `xcrun altool`:

```sh
Scripts/testflight.sh                 # archive, export, validate and upload
Scripts/testflight.sh --export-only   # stop at build/testflight/export/HotMess.ipa
```

- **Signing:** automatic, with team `DWVXMLB45Y` and an Apple Distribution
  certificate.
- **Build number:** the minutes since 2026-01-01 UTC unless `BUILD_NUMBER`
  is set. Keep it under 2,147,483,647: the API stores it in a 32-bit column.
- **API key:** the upload uses the App Store Connect API key garage-rag
  uses. That's the login keychain item with service
  `me.rickmark.garage-rag.asc-api-key`, or `ASC_KEY_ID`, `ASC_ISSUER_ID` and
  `ASC_KEY_PATH`.

## Known follow-ups

- The bundled Proxima Nova faces are referenced by the PostScript names
  `ProximaNova-Regular` and `ProximaNova-Semibold` in `Theme.swift`. If those
  names do not match the font files, SwiftUI falls back to the system face
  silently — worth confirming on a device.
- Sign-in requests `public_profile`, `email` and `user_friends`. The original
  also asked for `user_events` and `user_likes`, which Facebook has since
  removed, and for a `rsvp_event` publish permission that no longer exists —
  RSVPs now go to the Hot Mess API only. Confirm the permission set against the
  Facebook app configuration.
