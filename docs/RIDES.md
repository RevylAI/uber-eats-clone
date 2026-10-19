# Native Rides

The repository contains two independent iOS 17+ SwiftUI applications. Eats and its offline ordering behavior are unchanged. `apps/rides/project.yml` generates the `RidesDemo` scheme and bundle `com.revyl.ridesdemo`, with display name **Rides**. Internal target names and legacy wire values remain compatible with older builds; the normal app has no pairing screen or test banner.

## Accounts and trips

Create an account with a name, email, and a password of 12–128 characters, or sign in to an existing account. Choose Ride or Drive only at registration; the database fixes that account's role. Drivers provide a vehicle description and license plate. Account details come from the database rather than editable local placeholders. Email verification, password recovery, and independent driver verification are not integrated.

Both roles use the existing `landseer-enga/uber-clone` Convex production service at `https://harmless-mammoth-742.convex.cloud`. Only that public URL is bundled. No admin credential, invitation, fixed user, or password ships in the app. Passwords use independently salted scrypt; opaque, revocable account sessions expire after 30 days and are stored in the iOS Keychain. Sign out revokes the session and takes a driver offline; an active ride must first be completed or cancelled.

1. Sign into a rider account on one phone and a separately registered driver account on another. Normal registration uses the Austin service area.
2. The driver taps **GO**. The rider selects a destination, service, payment preference, and pickup, then confirms the request.
3. The online driver accepts the request. Assignment is atomic: competing drivers cannot both accept, and one driver cannot take two riders' active trips.
4. Both users can exchange messages. The assigned driver marks arrival, starts, and completes the ride. The rider can record a rating and tip preference.
5. Cancellation is available before the trip starts and records a zero-charge history entry. Once started, the assigned driver completes the trip.

Riders see only their own trip history. Drivers see bounded requests in their service area and their own assigned trips, not other riders' completed history or messages. Account history returns the latest 20 trips, retaining an active trip even when it is older; drivers may additionally see up to 20 pending offers. There is no account lifetime trip cap. Request UUIDs remain idempotent after their trip leaves the history window. Area-wide revisions prevent older snapshots from overwriting newer changes.

The pinned ConvexMobile 0.8.1 SDK supplies live dispatch subscriptions. Backgrounding cancels observation; foregrounding restores it. Network failures retain the secure session and last state without inventing acceptance, messages, or trip progress. Bookmarks, reminder preferences, and payment preferences remain local to the phone.

## Builds and independent proofs

| Project root | Profile | Build output |
| --- | --- | --- |
| Repository root | `pull-request` | `build/Build/Products/Debug-iphonesimulator/EatsClone.app` |
| `apps/rides` | `rides` | `build/Build/Products/Debug-iphonesimulator/RidesDemo.app` |

Run `revyl config validate` at the repository root and `revyl -C apps/rides config validate` for Rides. Build with `revyl build --profile pull-request --platform ios` or `revyl -C apps/rides build --profile rides --platform ios`. Each root owns its app, session hook, changed-path triggers, and proof policy. A proof never requires the other binary's screens.

The Rides single-phone proof registers a fresh real database rider in a unique test service area. It covers the normal signed-in Home, hosted request, cancellation, history, tabs, and profile. It must not claim driver acceptance, chat, or completion without a second separately registered driver in that same area. Launch variables and account sessions must never appear in public evidence.

Eats and Rides automation stays in Revyl Benchmarks. The Uber Revyl account is not connected to this GitHub repository, and its proposed migration was cancelled. Session launchers honor the selected `REVYL_API_KEY` or CLI login; the presence of `REVYL_UBER_API_KEY` must not switch accounts. Keep the existing project/app identities and Git-managed configuration authority intact. See [Revyl setup](REVYL.md).

## Isolated two-user verification

The Debug-only Revyl gate resumes an already registered database account; it does not create a room or grant a role. It requires a separate per-launch gate token plus the real account session, then verifies the server's identity, role, name, and expiration. Release builds ignore the gate.

```sh
python3 apps/rides/scripts/start-session.py --role rider --accounts-file "$PRIVATE_RUN_DIR/pair.json" --build-version-id "$RIDES_BUILD_VERSION_ID"
python3 apps/rides/scripts/start-session.py --role driver --accounts-file "$PRIVATE_RUN_DIR/pair.json" --build-version-id "$RIDES_BUILD_VERSION_ID"
```

Set `PRIVATE_RUN_DIR` to a new private directory outside Git for this run, and `RIDES_BUILD_VERSION_ID` to the exact Benchmarks Rides preview build under test. Run the commands in order: the first registers distinct rider/driver users through the public account action in one fresh service area and creates a private `0600` file; the second reuses the other user's real session. No admin key is needed. The file contains sensitive sessions, not passwords: do not attach it or share it across concurrent proofs. Without `--accounts-file`, each launch gets an independent account and area, so unrelated proofs cannot match one another. The launcher reads the app ID from the nested config, captures raw CLI output, and prints only safe session metadata.

The automatic `prepare-revyl-session.py` hook similarly registers a fresh rider and emits launch values only to Revyl's private hook channel. It fails closed without partial output if registration fails. Checkout-less sessions need compatible private launch values; expired account sessions cannot be used as permanent fixtures.

### Paired proof orchestration

Use fresh accounts per proof rather than permanent rider/driver session tokens in organization launch variables. Both phones receive `RIDES_AUTH_BYPASS_ENABLED=true`, an independent random `RIDES_AUTH_BYPASS_TOKEN`, and their own `RIDES_ACCOUNT_SESSION`. Each deep link selects the matching `rider` or `driver` role, which is verified against the database account. Sharing a service area makes the rider's new request discoverable by its paired online driver; it does not fabricate acceptance or bypass assignment rules.

Launch variables alone do not provision a second device. The current automatic proof configuration starts one rider phone. To automate paired changes, the proof runner must provision both phones on the same preview build, retain the two session IDs as distinct actors, and let its agent control and observe each one. It should take the driver online through the UI, request as the rider, accept as the driver, and assert that both screens agree. A missing second device is an explicit coverage gap, not a passing paired proof. This repository does not configure a multi-device proof runner.

At teardown, cancel or finish active rides, sign out both account sessions, stop only the two owned Revyl devices, and delete the private pair file. Removing that file does not revoke its database sessions. Do not publish passwords, account session tokens, gate tokens, or raw launch payloads in logs or evidence.

## Verification commands

```sh
cd services/ride-convex
npm ci && npm run typecheck && npm test && npm audit
cd ../..
python scripts/test_revyl_config.py
python -m unittest discover -s apps/rides/scripts -p 'test_*.py'
```

On an Apple Silicon Mac, `cd apps/rides && bash scripts/build-ios.sh` runs Swift core tests in Debug and Release and builds the app/test bundle. `bash scripts/verify-ios.sh` additionally executes iPhone simulator XCTest, including a real Keychain round trip. ConvexMobile 0.8.1 does not include an Intel simulator slice. Simulator builds are ad-hoc signed with the simulator-specific entitlement; do not disable signing or weaken Keychain tests. GitHub's Rides workflow runs Convex, legacy service, and actual simulator tests independently. CI does not deploy or need an admin token.

Backend deployment instructions and API contracts are in [`services/ride-convex`](../services/ride-convex/README.md). The older invitation-room Convex API and HTTP/SQLite service remain for older clients and regression tests, but the current UI does not expose them.

## Scope and limits

This is an independent app, not a verified transport or financial service. Maps are original Austin route illustrations, not GPS tracking or routing. Matching connects registered app users; it does not dispatch real vehicles. Driver identities and vehicle details are not independently verified. Payment preferences and fare/tip records do not authorize cards, transfer money, or create payouts. Reservations record a requested time without automatic timed dispatch. Phone calls, emergency response, email recovery, push notifications, and background delivery are unavailable. These limits appear in contextual Help, About, Wallet, and receipt screens rather than global demo warnings.

The rider structure was informed by indexed Uber flow references; exhaustive, version-pinned parity has not been established. The driver dashboard is original. No Mobbin screenshots, Uber logos, or proprietary fonts are bundled. The Eats shortcut opens the separate installed Eats application.

See [verification evidence](RIDES_VERIFICATION.md) for completed checks and outstanding gates.
