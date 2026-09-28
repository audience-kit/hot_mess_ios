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

- **Networking.** `APIClient` is an actor wrapping `URLSession` with
  `async`/`await`. Calls are described as `Endpoint<Response>` values and
  surfaced through `HotMessAPI`, which returns concrete models and throws
  `APIError`. The client raises an event when the server rejects the bearer
  token; `SessionStore` listens and signs the user out.
- **Models.** Every payload is a `Sendable`, `Codable` struct. Dates accept both
  the API's `yyyy-MM-dd'T'HH:mm:ss.SSSZ` format and plain ISO 8601, and IDs that
  Facebook sends as either a string or a number decode from both.
- **Concurrency.** Services are actors or `@MainActor` types; there are no
  shared mutable singletons behind the UI.

## Environments

`Debug`, `Staging` and `Release` build configurations map to the three
`.xcconfig` files in `Configurations/`, which set the API host, Facebook app ID,
bundle suffix and APNs environment. Four shared schemes select between them.

`FACEBOOK_CLIENT_TOKEN` is intentionally empty in each configuration: copy the
client token for each environment out of the Facebook app dashboard
(Settings → Advanced → Client token). The Facebook SDK reports an error at
runtime while it is blank.

## Tests

`HotMessTests` runs entirely offline: model decoding against inline fixtures,
endpoint URL construction, deep-link parsing, geometry and formatting. Run them
with any scheme, or:

```sh
xcodebuild test -scheme "HotMess Debug" -destination "platform=iOS Simulator,name=iPhone 16"
```

The previous suite authenticated against Facebook with a token committed to the
repository and then called the live API, so it could not run offline and could
not distinguish a regression from an outage.

## Known follow-ups

- The 1024×1024 marketing icon in `AppIcon.appiconset` is a JPEG. App Store
  Connect requires PNG; it needs re-exporting.
- The bundled Proxima Nova faces are referenced by the PostScript names
  `ProximaNova-Regular` and `ProximaNova-Semibold` in `Theme.swift`. If those
  names do not match the font files, SwiftUI falls back to the system face
  silently — worth confirming on a device.
- Sign-in requests `public_profile`, `email` and `user_friends`. The original
  also asked for `user_events` and `user_likes`, which Facebook has since
  removed, and for a `rsvp_event` publish permission that no longer exists —
  RSVPs now go to the Hot Mess API only. Confirm the permission set against the
  Facebook app configuration.
