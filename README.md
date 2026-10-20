# Eats and Rides

Two independent native SwiftUI apps for iOS 17 and later in one repository: an offline food-ordering app and an account-backed rider/driver app. Their designs take inspiration from Uber and Uber Eats references on Mobbin; this project is not affiliated with or endorsed by those companies.

| App | Source and scheme | Data |
| --- | --- | --- |
| **Eats** | Repository root · `EatsClone` | Bundled restaurant catalog and local `UserDefaults` snapshot; no backend or API key required. |
| **Rides** | [`apps/rides`](apps/rides) · `RidesDemo` | Registered rider/driver accounts, Keychain sessions, and shared trips on the hosted [Convex backend](services/ride-convex). Requires network access. |

The apps have separate bundles, build recipes, and Revyl projects. Adding Rides does not replace Eats. Neither app is a production ordering, transport, or financial service, and exhaustive Uber feature parity is not claimed.

## What works

**Eats:** onboarding, restaurant discovery, menus, item customization, cart, local checkout, simulated order progress, favorites, and order history. Its snapshot persists on the same installation under `eats.local.snapshot.v1`. Checkout does not contact a restaurant or charge a card; all prices, delivery estimates, payment labels, and progress are illustrative. Pass `--reset-demo` or reinstall to reset local data. See [scope](docs/PARITY.md), [roadmap](docs/ROADMAP.md), and [design references](docs/REFERENCES.md).

**Rides:** normal registration/sign-in, immutable rider or driver roles, saved places, destination/pickup selection, service and payment preferences, requests, driver acceptance, two-way chat, arrival/start/completion, history, receipts, rating/tip preferences, and cancellation before a ride starts. Separate database users share the trip; acceptance and lifecycle changes come from the assigned driver's actions, not simulated progress. Signup shows field-specific validation and the 12–128-character password requirement. Accounts use server-side salted password hashes and revocable, 30-day sessions stored in Keychain.

Rides uses Apple MapKit tiles with dashed route previews, not driving directions, live GPS, or moving vehicle tracking. Fare/tip records and payment preferences do not transfer money or create payouts. Reservations do not automatically dispatch at the requested time. Calls, emergency response, email recovery, independent driver verification, and push/background delivery are not integrated. See [Rides setup and limitations](docs/RIDES.md).

## Build and run

Use a Mac with a current Xcode release, an installed iOS 17-or-later simulator runtime, and [XcodeGen](https://github.com/yonaskolb/XcodeGen). **Rides requires Apple Silicon:** its pinned ConvexMobile 0.8.1 SDK has no Intel simulator slice.

From the repository root:

```sh
brew install xcodegen

# Eats: core tests, generated Xcode project, and simulator app/test bundle.
bash scripts/build-ios.sh

# Rides: Debug/Release core tests and signed arm64 simulator app/test bundle.
(cd apps/rides && bash scripts/build-ios.sh)
```

Open `EatsClone.xcodeproj` or `apps/rides/RidesDemo.xcodeproj`, select the corresponding scheme and an installed simulator, then choose Run. The scripts generate these projects from their respective `project.yml` files; building alone does not launch either app or execute iOS simulator XCTest.

| App | Simulator build output |
| --- | --- |
| Eats | `build/Build/Products/Debug-iphonesimulator/EatsClone.app` |
| Rides | `apps/rides/build/Build/Products/Debug-iphonesimulator/RidesDemo.app` |

These `.app` bundles are for simulators, not physical iPhone installation. Rides bundles only the hosted backend's public URL; no Convex admin token or fixed account is needed to run it. Register a rider on one phone and a driver on another, take the driver online, then request and accept a ride. See [the two-user guide](docs/RIDES.md#accounts-and-trips) for the complete flow.

## Run checks

Execute the app's actual iPhone simulator XCTest suite on a Mac with an available simulator:

```sh
bash scripts/verify-ios.sh
(cd apps/rides && bash scripts/verify-ios.sh)
```

Backend and helper checks can run separately; use Node 24 and Python 3 with `PyYAML==6.0.3` installed for the configuration tests:

```sh
(cd services/ride-convex && npm ci && npm run typecheck && npm test)
(cd services/ride-demo && npm test)
python3 scripts/test_revyl_config.py
python3 -m unittest discover -s apps/rides/scripts -p 'test_*.py'
```

[`services/ride-demo`](services/ride-demo) is the legacy HTTP/SQLite implementation retained for compatibility and regression tests; it is not the current Rides app's backend. Backend deployment and API details live in the [Convex README](services/ride-convex/README.md).

## Revyl previews and device evidence

GitHub-integrated automation remains in **Revyl Benchmarks**, with independent Eats and Rides configurations. Uploading an explicitly requested artifact to another Revyl app does not migrate this integration.

| App | Configuration | Build profile |
| --- | --- | --- |
| Eats | [`.revyl/config.yaml`](.revyl/config.yaml) | `pull-request` |
| Rides | [`apps/rides/.revyl/config.yaml`](apps/rides/.revyl/config.yaml) | `rides` |

With the authorized Revyl CLI account, run from the repository root:

```sh
revyl config validate
revyl -C apps/rides config validate
revyl build --profile pull-request --platform ios
revyl -C apps/rides build --profile rides --platform ios
```

Each project owns its app, session hook, path triggers, and Proof of Changes policy. No GitHub Actions API key is required for Revyl-managed builds. Enabled configuration is not evidence that a particular proof passed; use the actual PR report. See [Revyl session setup and security](docs/REVYL.md), [Eats verification](docs/VERIFICATION.md), and [Rides verification](docs/RIDES_VERIFICATION.md) for evidence and its build-specific limits.

For paired Rides checks, use two separately registered database users in the same isolated test service area and explicitly target each phone. The [isolated two-user instructions](docs/RIDES.md#isolated-two-user-verification) provision the accounts against a specified build. A single-phone request/cancellation proof does not verify driver acceptance, shared chat, or completion.

**When a feature is developed or checked on a Revyl device, include that device context in the PR description:** source commit/build, device/OS and actor roles, embedded public-safe screenshots or recordings, the actions and results they demonstrate, and any failures or untested paths. Keep older-build evidence explicitly attributed rather than presenting it as current-head coverage. The [PR template](.github/pull_request_template.md) and [agent instructions](AGENTS.md) capture this requirement. Never publish account emails, passwords, session/gate tokens, raw launch payloads, or signed download URLs.

## License and media

Source code is available under the [MIT License](LICENSE). Bundled food photographs are separate third-party works covered by the [Unsplash License](https://unsplash.com/license), **not MIT**; see [photo sources and licensing](docs/PHOTOGRAPHY.md). Photos are bundled rather than downloaded at runtime and do not depict or endorse the named restaurants' actual dishes.

Mobbin screenshots, Uber logos, and proprietary fonts are not bundled. Product and restaurant names are references or sample content; their trademarks belong to their respective owners. Do not enter real payment details or sensitive personal information.
