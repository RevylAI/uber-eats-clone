# Native rides and paired-phone demo

The repository contains two independent iOS 17+ SwiftUI applications. The original `EatsClone` target and its offline ordering behavior are unchanged. `apps/rides/project.yml` generates `RidesDemo.xcodeproj`, scheme `RidesDemo`, bundle `com.revyl.ridesdemo`, display name **Rides**. One Rides binary has rider and driver modes; install it on both phones.

## Build profiles

The apps share this Git repository, but each has its own Revyl project root, session setup, and automatic PR proof policy:

| Config | Profile | Revyl app | Build command and output, relative to its project root |
| --- | --- | --- | --- |
| `.revyl/config.yaml` | `pull-request` | Eats, `ecced7bf-9a43-4a8b-9a26-c072fa7bad74` | `bash scripts/build-ios.sh` → `build/Build/Products/Debug-iphonesimulator/EatsClone.app` |
| `apps/rides/.revyl/config.yaml` | `rides` | Rides, `1f375e45-bf9b-434a-b939-a8892a2297c3` | `bash scripts/build-ios.sh` → `build/Build/Products/Debug-iphonesimulator/RidesDemo.app` |

```sh
revyl config validate
revyl -C apps/rides config validate
revyl build --profile pull-request --platform ios
revyl -C apps/rides build --profile rides --platform ios
```

The root project remains Eats-only; run Rides CLI commands with `-C apps/rides` or from that directory. Revyl selects the nearest config, so each app gets its own sign-in rather than inheriting the Eats hook. Project `b13e33ff-5c8d-490e-bb24-9ef1d4c06bba` is registered at `apps/rides`, with independent preview builds, Revyl-harness Proof of Changes, strict build checks, and triggers for Rides and its shared service. Eats triggers cover its own source and configuration. A change touching both sets of paths is eligible for both projects.

The Rides project was published in manual authority so automation can run before the config reaches `main`. Once Revyl reconciles its designated config from `main`, Git becomes authoritative. The existing root project is already Git-managed; its updated published aggregate follows `main`, while PR candidate configuration is validated at the exact PR head. Do not use a force-push of server configuration to bypass Git authority.

Rides automatic proof exercises independent Rider sign-in, offline booking through pickup confirmation, the connection-required boundary, tabs, saved places, and wallet. It deliberately does not claim to verify a two-phone trip without a reachable shared service and a second phone. Paired dispatch, chat, completion, and cancellation were verified separately on native phones. This setup does not deploy a permanent backend or establish full Uber parity.

On a Mac, `cd apps/rides && bash scripts/build-ios.sh` runs the core tests in Debug and Release and builds the iOS app and test bundle. Simulator builds are ad-hoc signed with a simulator-specific Keychain identity; an unsigned simulator app cannot save the shared session. `bash scripts/verify-ios.sh` additionally executes XCTest, including a real Keychain round trip, on an installed iPhone simulator. The cloud build recipe compiles but does not execute iOS XCTest. The `Rides demo` GitHub workflow runs server tests and the simulator verification separately, on pull requests and pushes to `main`.

## Shared service

Two phones cannot synchronize through per-device stubs. `services/ride-demo` is a dependency-free Node 24 HTTP service with SQLite/WAL persistence. It stores isolated invitation rooms, per-participant bearer credentials (hashed server-side), demo requests, acceptance, transitions, messages, and ratings. It never dispatches a real car or processes a payment. See its [API and hosting documentation](../services/ride-demo/README.md).

```sh
cd services/ride-demo
npm test
npm start
```

For persistent demos, run its Docker image behind HTTPS and mount `/data` on durable storage. Both phones need the same reachable HTTPS origin. A temporary workspace preview is useful for verification but is not permanent hosting: the workspace can sleep, the process can stop, and phones then show a connection error. No transient backend address or invitation is hardcoded in the app.

## Pair two phones

1. Install the same Rides build on both iPhones. On the rider, tap **Connect two-phone demo** or **Account → Rider & driver demo**. Choose **Rider**, enter the service's HTTPS address and a sample name, and tap **Create rider room**.
2. Keep the invitation private. On the second phone, choose **Driver**, enter the same service address and the rider's room code, and tap **Join as Driver**. Tap **GO** to become available.
3. On the rider, tap **Where to?**, select an offline demo destination, choose a service and payment label, then confirm pickup. The request must appear on the driver phone; nothing accepts it automatically.
4. Tap **Accept ride** on the driver. The rider must change to the assigned driver, vehicle, and plate. Use **Message driver/rider** to send messages between the phones.
5. The driver taps **I've arrived**, **Start**, and **Complete ride**. The rider observes each server-committed state after the next poll. The rider can submit a rating and demo tip; receipts and the driver's demo earnings update from shared state.
6. For a separate cancellation case, rebook and cancel before the trip starts. Both phones must reflect cancellation. No fee is charged. A ride cannot be cancelled after starting; the assigned driver completes it.

Each room permits one active trip. Competing online drivers cannot both accept it. The client polls once per second while foregrounded and discards older room revisions. Network failures do not locally fake acceptance or advance a trip. Credentials are kept in Keychain; bookmarks, the default payment label, and in-app reminder preferences stay in UserDefaults. Driver identity persists with its saved session; a new driver join creates a different participant.

## Isolated Revyl sign-in

Each project owns its session hook. The root hook mints an Eats buyer token; `apps/rides/scripts/prepare-revyl-session.py` mints a fresh Rides token. Rides preview sessions without a checkout use the separate `RIDES_AUTH_BYPASS_ENABLED` and encrypted `RIDES_AUTH_BYPASS_TOKEN` organization launch references. They never replace the Eats variables. The automatic Rides proof defaults to Rider. The explicit launcher selects either Rider or Driver from the nested project:

```sh
python3 apps/rides/scripts/start-session.py --role rider --server https://your-demo-server.example
python3 apps/rides/scripts/start-session.py --role driver --server https://your-demo-server.example
```

Pass `--build-version-id` to pin a build. Pass the rider's invitation with `--room` to join automatically. The launcher mints an independent token per phone, supplies it at app boot, and uses `ridesdemo://revyl-auth` with the requested allowlisted role. It captures raw CLI output and prints only safe session metadata, never the token or deep link. The fixed fresh-session names are Alex Morgan (rider) and Jordan Lee (driver). The bypass selects a demo role; it is not production authentication or a fixed global backend account. The handler is Debug-only, explicitly enabled and token-gated, with role, route, and parameter allowlists. Session creation can queue if the Revyl workspace has no capacity.

## Reference coverage and limits

The supplied [Uber iOS release](https://mobbin.com/apps/uber-ios-51d7d6f1-1a92-4d18-bb0c-0958f4d14598/d3962942-f984-494a-91bc-1d31f6e974e9/flows) redirects to a login page in this workspace's browser. The connected Mobbin search API supplied indexed Uber iOS flow metadata and screenshots; it did not provide an exhaustive version-pinned inventory. This implementation follows the core rider screen structure, not every Uber product or a claimed pixel-perfect reproduction. The driver dashboard is an original companion design, not a reproduction of Uber Driver screens.

| Indexed reference | Demo implementation |
| --- | --- |
| [Booking a ride](https://mobbin.com/flows/c54d8dfb-8f67-4e82-afb6-7943d8886c5b) | Rides/Eats header, destination suggestions, pickup/destination, up to two stops, vehicle tiers, sample fares, payment selection, pickup confirmation, request and tracking states, rating and tips |
| [Reserving a ride](https://mobbin.com/flows/41341864-d3d9-4d31-b37e-840222b27239) | Date/time picker and reservation details; limited to 30 days; visible immediately to the driver and manually advanced, not timed dispatch |
| [Cancel reservation](https://mobbin.com/flows/7476e6b7-36ea-4a61-8da5-7fa55fcb41f0) | Reason selection and explicit keep/cancel actions before trip start; no real fee |
| [Message driver](https://mobbin.com/flows/c447156b-3263-43fb-8801-cb44fdf3beac) | Shared chat, quick replies, privacy warning; no VoIP, SMS, or automatic replies |
| [Activity](https://mobbin.com/flows/c8c8b75b-d49a-430a-9581-3bc669f3ce74) | Active/reserved ride, shared past trips, filters, receipt, and rebook |
| [Account](https://mobbin.com/flows/8b0e61f3-f4e6-4f64-bbf4-d9df7a247326), [Wallet](https://mobbin.com/flows/5d2557e7-3e74-4bfa-b5d0-ad40ef66f371), [Settings](https://mobbin.com/flows/56e8bd16-f5b3-41fc-af23-c5c7064ca6b6) | Demo profile, method selection, example balance, saved locations and preferences; no real card entry or balances |
| [Help](https://mobbin.com/flows/a7808204-ebf4-4030-8ae0-cb0d63b96806), [Safety toolkit](https://mobbin.com/flows/532bd6f4-1a97-4edf-8080-4bf347f3007b) | Demo help, trip detail sharing and explicit safety limitations; no live support, emergency calls, audio, crash detection, or PIN verification |

Not implemented: exhaustive onboarding/auth parity, group invitations and contact switching, rentals, bikes/scooters, memberships, family/business profiles, promotions, real maps/geocoding/GPS, live dispatch or matching, payment settlement, and background/push delivery. Maps and all travel estimates are original offline illustrations. The Eats shortcut opens the separate installed Eats demo; if absent, it explains how to install it. No Mobbin screenshots, Uber logos, or proprietary fonts are bundled.

See [verification evidence](RIDES_VERIFICATION.md) for checks actually completed and outstanding gates.
