# Rides verification

Verified on October 18, 2026. No real ride, charge, call, or location tracking is performed.

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
