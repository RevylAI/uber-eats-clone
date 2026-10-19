# Rides verification

No real ride, charge, call, or location tracking is performed.

## Hosted Convex deployment — October 19, 2026

The existing `landseer-enga/uber-clone` production deployment is `https://harmless-mammoth-742.convex.cloud`. The CLI deployed the schema, seven indexes, and six public ride functions; inspection confirmed `rooms`, `participants`, `credentials`, and `trips` tables. No replacement project was created and no existing project was deleted. The production service does not depend on a workspace process.

The backend passes 45 Convex tests, TypeScript checking, and an npm audit with no vulnerabilities. Independent clients against the actual production deployment additionally verified live subscriptions, server-authoritative fares, booking idempotency/conflicts, exactly one winner from competing driver acceptance, assigned-driver permissions, two-way chat, arrival/start/completion, five stars and a $3 demo tip, cancellation, room isolation, invalid-token rejection, and history retrieved through a newly created client. Those live checks are separate from the mock transaction tests.

Native Swift build `86cf5c9d-c5a3-4d9b-ad71-6438bc59cd02` ran core tests in Debug and Release and built the arm64 simulator app/test bundle. Two independent native phones against Convex created/joined a private room, went online, requested and accepted a ride, exchanged both chat messages, and advanced arrival, start, and completion. A cold-launched rider also restored an accepted active trip from Keychain without creating a new room or credential. The initial generic simulator build exposed the SDK's missing Intel slice; the Rides build now explicitly targets arm64. Eats builds are unchanged.

The current PR's checks and native evidence remain authoritative for subsequent client changes. The new regression coverage includes cached/offline connection state, subscription cancellation, expired query and mutation credentials, and retaining receipt focus after restoring an active trip. Current Rides automation uses the hosted backend for a single-phone request/cancellation, not an invented driver acceptance; paired behavior still requires two phones.

Rooms have a 24-hour authorization lifetime and bounded history; expiry is not automatic document deletion. Authentication uses private demo-room capabilities, not verified real identities. Real maps, GPS, matching, payments, and background/push delivery remain out of scope.

## Original HTTP baseline — October 18, 2026

The results below describe the earlier SQLite/HTTP implementation and its temporary verification server, not the hosted Convex deployment above.

## Automated checks

- [Native simulator CI](https://github.com/RevylAI/uber-eats-clone/actions/runs/39191580033/job/117865343290) at `7c4fa9d` passed: 16 Swift core tests in Debug, 16 in Release, then **17 iOS XCTest cases**, including `testSimulatorKeychainCanSaveRestoreUpdateAndClearSession`. The log ends with `TEST EXECUTE SUCCEEDED`; this is executed simulator testing, not just `build-for-testing`.
- Six Node 24 HTTP integration tests pass. Coverage includes cross-client lifecycle, exclusive concurrent acceptance, idempotency, invitation/room isolation, assignment and role enforcement, chat/cancellation rules, schedule/route validation, and SQLite restart persistence.
- The repository-root `rides` build succeeded for app `1f375e45-bf9b-434a-b939-a8892a2297c3`: job `42e5b4e7-4482-4422-8e66-ce2909d27bc3`, version `94a524ee-0761-44a2-83de-f39cffeecc4f`. The recipe tests the core, compiles the app/test bundle, checks the packaged URL scheme, and verifies its ad-hoc signature.
- The original two-profile root configuration passed connected validation. Setup now uses independent project configs: root Eats and nested `apps/rides`. Both pass connected validation; the nested Rides project is published with independent PR automation, and the root remains Git-managed. Eats app code and buyer sign-in are unchanged.

## Native paired-phone behavior

Two fresh iOS sessions in the user's Revyl workspace installed the configured rides build above, rather than the separate Capy-managed build. The isolated launchers visibly accepted Rider and Driver sign-in. The following actions were performed in the actual native UI:

1. The rider created a room and securely saved its session. The driver entered the private invitation, joined the same room, and went online.
2. The rider selected 701 Brazos Street → Austin–Bergstrom International Airport, chose UberX, and confirmed the $18.40 demo fare. The rider showed **Finding your ride** and the driver independently showed **New ride request**, Alex Morgan, matching route and fare.
3. The driver tapped **Accept ride**. Its screen changed to **Head to pickup**; the rider changed to **Your driver is on the way**, Jordan Lee, Toyota Prius, plate **DEMO 24**.
4. The rider sent **I'm here** and the driver sent **Be right there**. Both phones displayed both messages with the correct sender names.
5. The driver marked arrival and started the ride. The rider showed **Your driver has arrived**, then **You're on your way**. Driver completion opened the rider receipt and changed driver earnings to $18.40.
6. The rider submitted five stars and a $3.00 demo tip. Rider Activity showed $21.40, and the driver's earnings updated to $21.40.
7. The rider rebooked. The second request appeared on the driver, then disappeared after the rider confirmed cancellation. The rider showed **Your ride was cancelled** with its reason; driver Activity recorded **$0.00 · Cancelled** alongside the completed $21.40 trip.
8. An invalid-token native deep link was rejected with **Revyl sign-in rejected: Invalid session token**. The driver's existing role and trip history remained intact.

The first unsigned build could reach the service but failed to save its session in Keychain. The build now uses simulator ad-hoc signing and a simulator-only entitlement file; the live Keychain XCTest and both native joins verify the fix. A final cancellation summary correction removes active pickup instructions and shows zero charges on cancelled trips.

Screenshots of the actual native home, paired acceptance, shared chat, and receipt are attached to the pull request. Invitation codes, bearer tokens, launch gates, and signed artifact URLs are deliberately omitted from published evidence.

## Limits

- The verification server is a temporary HTTPS workspace preview. Persistent demos require a separately hosted instance with durable SQLite storage; restarting or sleeping the workspace is not permanent hosting.
- Disabled-gate, malformed-link, unauthorized-role/route, and production rejection are covered by core tests. Only accepted rider/driver roles and wrong-token rejection were additionally exercised on phones.
- The full version-pinned Uber reference inventory and exhaustive parity have not been established. The driver dashboard is an original companion, and several real Uber products/integrations are intentionally absent; see [scope and setup](RIDES.md).
- Automatic Revyl Proof of Changes is configured separately for Eats and Rides. Rides proof covers Rider sign-in, offline booking and navigation, and the required-connection boundary. A configured policy is not a completed proof, and this single-phone policy does not establish automated two-phone proof generation.
