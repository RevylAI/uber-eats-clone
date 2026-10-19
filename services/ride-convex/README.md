# Transactional rides backend

Convex 1.47.0 implementation of `services/ride-demo/server.js`, using the JSON shapes in `apps/rides/Core/RideModels.swift`. This package contains no deployment credentials, project provisioning, Swift changes, or admin endpoints.

## Local verification

```sh
cd services/ride-convex
npm ci
npm run codegen
npm run typecheck
npm test
```

Tests use `convex-test` with transaction limits enabled. Legacy room tests use Vitest's edge runtime; account/dispatch tests use Node to exercise the real Node crypto actions. They do not require a Convex account, local deployment, environment variables, or network access after installation. Concurrent test calls exercise the mock backend's serialized transactions; production conflict retries and live subscriptions still require integration verification against a deployment.

Static `_generated` bindings are checked in. Convex 1.47.0's ordinary `codegen` command requires an existing deployment selection. The npm script instead uses that version's offline `--system-udfs` code-generation path, with deployment/access-token variables explicitly removed. It generates schema-derived data model types, typed function references, and the standard server bindings without creating or contacting a deployment. The flag is an internal CLI feature pinned to this Convex version. Normal deployment/codegen can regenerate the same bindings later.

## Deploy to the existing project

The Rides app's public production URL is `https://harmless-mammoth-742.convex.cloud`, in team `landseer-enga`, project `uber-clone`. Do not create another project or commit an admin credential. With a securely configured Convex personal access token (`CONVEX_OVERRIDE_ACCESS_TOKEN`) or an authenticated CLI session:

```sh
npm ci
npx convex deployment select landseer-enga:uber-clone:dev
npx convex deploy --dry-run --typecheck enable --yes
npx convex deploy --typecheck enable --yes
```

Selection writes ignored local configuration and chooses the existing project's development deployment; `deploy` targets that project's default production deployment. Confirm that the dry run names `harmless-mammoth-742` before deploying. Deployment regenerates bindings, validates the schema, and publishes functions and indexes. Regular app clients need only the public URL and their own private demo-room session, never this admin token. Eats uses neither this deployment nor its credentials.

## Account and dispatch API

New clients use accounts and dispatch, without invitations, shared identities, or room creation. Existing `rides:*` functions and tables remain compatible with older room clients; their credentials cannot authenticate account functions and account credentials cannot access legacy rooms.

| Function | Kind | Arguments | Result |
| --- | --- | --- | --- |
| `accounts:signUp` | action | `{ name, email, password, role, vehicle?, plate?, serviceArea? }` | extended `RideSession` |
| `accounts:signIn` | action | `{ email, password }` | extended `RideSession` |
| `accounts:resume` | query | `{ token }` | extended `RideSession` |
| `accounts:profile` | query | `{ token }` | account |
| `accounts:signOut` | mutation | `{ token }` | `true` |
| `dispatch:state` | query | `{ token }` | `RideRoomState` |
| `dispatch:availability` | mutation | `{ token, online }` | `RideRoomState` |
| `dispatch:book` | mutation | exactly the `rides:book` envelope below | `RideRoomState` |
| `dispatch:act` | mutation | exactly the `rides:act` envelope below | `RideRoomState` |

The extended session is `{ roomCode, participantId, token, role, name, state, account, expiresAt }`, with account `{ id, name, email, role, vehicle, plate }`. `account.id == participantId == roomCode` is the persistent database user ID. The `roomCode` field is only a legacy Swift binding, **not an invitation**. Session role/name match the account and come from the database. `expiresAt` is epoch milliseconds. Tokens are `user.` followed by 32 cryptographically random bytes encoded base64url (43 characters without padding). The prefix lets native clients distinguish account sessions from their older room credentials. `resume` returns the presented token and its original expiry, not a new session. Profile vehicle/plate are null for riders; drivers must supply both when registering. There is no profile or role-changing endpoint.

Email is trimmed, lowercased, and unique; names are trimmed and limited to 80 characters. Passwords are 12–128 characters, used verbatim without trimming. Driver vehicle and plate are limited to 100 and 20 characters. `serviceArea` defaults to `austin`; supplied areas are trimmed, lowercased, 1–80 characters matching `[a-z0-9][a-z0-9-]*`. A zone is only an offer-discovery boundary: selecting another user's zone never grants access to their assigned trips, histories, messages, or mutations. Normal UI registration should omit it. Parallel tests register a fresh rider **and** driver through `accounts:signUp` in the same `test-<uuid>` zone, then inject each real returned session into its Debug app or resume it with `accounts:resume`. There are no fixture accounts or administrative seeding secrets.

Node internal actions generate salts and credentials using `node:crypto.randomBytes`, derive 64-byte password hashes with salted scrypt (`N=32768, r=8, p=3`, random 16-byte salt), and compare with `timingSafeEqual`. The Node actions access the database only through internal mutations; no public password/hash lookup exists. Tables contain salted password hashes and SHA-256 **session** token digests, never plaintext passwords or session tokens. Each login creates a separate 30-day session. Sign-out returns 409 while the account has an active trip; otherwise it atomically takes a driver offline and deletes only the current session. Repeating a validly shaped revoked-token sign-out returns true without changing availability. Revocation and expiry are checked on every authenticated account/dispatch call. Expired rows are not automatically deleted, and subscription caching is not an expiry timer: clients must also clear expired local sessions.

An expired session may only delete its own expired credential during sign-out; it cannot change account availability or affect newer sessions. Sign-in atomically reserves at most five attempts per registered account per 15-minute window, including successful attempts, without extending the window on failures. Case variants share the same budget. Wrong passwords, unknown accounts, and throttled accounts all return `ConvexError({ status: 401, message: "Invalid email or password" })`; unknown/throttled accounts still perform dummy scrypt work. Unknown addresses do not create throttle records. Malformed envelopes return safe application errors. Argument envelopes use `v.any()` and manual validation to avoid credential echoes from framework validators. Application code does not log credentials; credentials necessarily traverse TLS and action arguments, so platform observability and client logging still require sensitive-data controls.

Dispatch trusts database identity and immutable role, never caller-supplied IDs or roles. Trips persist actual rider and assigned driver user references. One active-trip pointer per rider and per driver prevents simultaneous bookings and cross-rider double assignment in atomic transactions. Acceptance requires an online driver in the same area. Only the assigned driver advances the trip; only its rider/assigned driver may chat or cancel under the legacy lifecycle rules. Only its rider may rate or tip after completion. Driver snapshots use their registered vehicle/plate and a rating of 0 rather than fabricated reputation; aggregate reputation is not implemented.

Account snapshots include at most 20 recent history records (replacing the oldest with an older active trip if needed), at most 20 requested offers for drivers, and at most 32 online-driver IDs. An online driver always sees their own ID in that bounded list. All reads use scoped indexes. Riders see only their own trips. Drivers see only requested offers in their area and their own assigned recent/active trips, never other users' assigned histories or chats. An area-wide revision increases atomically on successful dispatch mutations so native clients can reject out-of-order snapshots, including discovery/availability changes from other accounts. Identical booking retries do not increase it. Old rows and rider-scoped request IDs remain stored, so identical booking retries remain idempotent even after a trip leaves the visible recent history; changed payloads return 409. Unlike legacy rooms, accounts have no lifetime trip cap. Fares, booking validation, message bounds, and lifecycle rules below also apply to dispatch.

This is real database-backed email/password authentication, **not a complete production identity or security system**. Emails are not verified; password recovery, email delivery, driver/license/background verification, identity proofing, payments, global/IP-based abuse protection, and automatic retention cleanup are absent. Driver names, vehicles, and plates are self-reported. Per-account throttling does not stop distributed signup or unknown-email scrypt denial of service, and a targeted account can be temporarily locked out. Production adoption requires independent security review, deployment verification, abuse controls, verified identity/recovery workflows, and a retention policy. No deployment or account provisioning is required for local verification.

## Legacy room public API

Legacy room functions live in `convex/rides.ts`. Function paths are `rides:createRoom`, `rides:joinRoom`, `rides:state`, `rides:availability`, `rides:book`, and `rides:act`.

| Function | Kind | Arguments | Result |
| --- | --- | --- | --- |
| `createRoom` | mutation | `{ name, token }` | `RideSession` |
| `joinRoom` | mutation | `{ code, role, name, token }` | `RideSession` |
| `state` | query | `{ token }` | `RideRoomState` |
| `availability` | mutation | `{ token, online }` | `RideRoomState` |
| `book` | mutation | `{ token, request: { requestId, pickup, destination, stops, service, paymentMethod, scheduledAt?, note } }` | `RideRoomState` |
| `act` | mutation | `{ token, tripID, action: { action, reason?, rating?, tipCents?, text? } }` | `RideRoomState` |

`RideSession` is `{ roomCode, participantId, token, role, name, state }`. The returned token is the exact client-supplied credential, not a server-generated replacement. `RideRoomState` is `{ roomCode, revision, driverOnline, onlineDriverIds, trips }`. Trips and messages contain only the Swift wire fields, never Convex `_id`, `_creationTime`, request fingerprints, or credential hashes. Nullable trip fields (`scheduledAt`, `driver`, `cancellationReason`, `rating`) are always present as JSON null until populated. Dates are UTC ISO-8601 strings with milliseconds. Optional request/action fields can be omitted; `scheduledAt` and cancellation `reason` can also be null.

Expected failures throw `ConvexError({ status, message })`: 400 for invalid input, 401 for missing/invalid/expired credentials, 403 for forbidden roles, 404 for an unavailable room or room-scoped trip, 409 for a conflicting operation or a full room, and 503 if invitation allocation fails. Error messages never include submitted credential values. Arguments are validated inside handlers to avoid framework argument-validation errors echoing a credential-containing argument envelope.

Use a Convex client subscription to `rides:state` for live updates. The query reads the room, every bounded room participant, and every bounded room trip through room-scoped indexes, so all room changes invalidate its result. Revisions increase for joins and successful state-changing mutations; an identical booking retry or an identical existing-token join does not increase the revision. Ordering is newest trip first by Convex insertion order. Expiry is checked on each function execution; a cached subscription is not a timer and clients should clear an expired local session rather than expect an expiry-only push.

## Legacy credentials and privacy boundary

The client must generate a fresh credential from cryptographically secure random bytes before creating or joining a room. Accepted credentials are 32–256 characters, used verbatim without trimming, and hashed with server-side SHA-256. Application tables persist only the hash and a participant reference. No application function logs credentials or stores plaintext credentials in documents or errors. Credentials are necessarily sent as Convex function arguments over TLS; handle client transport, platform access, and observability as sensitive infrastructure. Do not place tokens in URLs, logs, analytics, or repository files.

Rooms expire 24 hours after creation. Every credential expires no later than its room, and joining never extends the lifetime. Expired documents are inaccessible through the public functions but are not automatically deleted; expiry is an authorization boundary, not a retention/deletion policy.

Invitations are private, case-sensitive, 16-character capabilities using `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (80 bits). They are derived from the client's cryptographically random token using domain-separated SHA-256, mapped without modulo bias into the 32-character alphabet, and checked for collisions inside the transaction. The invitation digest is independent of the stored credential digest; the token cannot be recovered from the invitation. This relies on the required secure client token generation, not on ordinary JavaScript randomness. Non-secret participant/trip/message identifiers use Convex's strong seeded PRNG. Sharing an invitation permits someone to join as the existing rider or as a new driver and read that room's full trip history. A rider join preserves the original rider's identity and name; drivers receive separate identities. Reusing a token is allowed only for an idempotent join to the same room and role. Tokens cannot be reassigned across rooms or roles.

This is private-capability demo authentication, **not production user authentication**. There is no verified user identity, membership approval, per-IP rate limiter, payment processing, or abuse-prevention service. Production use needs an authenticated identity and invitation-management policy, abuse protection at ingress, and an explicit data-retention policy. The public functions offer no administrative database access.

## Legacy room business rules and bounded reads

Each room has one rider, at most 31 distinct drivers, at most 128 credentials, and at most 20 lifetime trips. Each trip has at most 100 messages. Reaching a cap returns 409 rather than deleting history, invalidating old credentials, or weakening request-id idempotency. Start a new room for another demo. These caps keep full-room snapshots bounded even with maximum-length Unicode strings and full chat histories; there is no hidden partial-history pagination.

All state changes are single Convex transactions. The room's active-trip pointer prevents concurrent bookings; acceptance reads and writes the same trip atomically, so only one online driver can win. Only the assigned driver can arrive, start, or complete. Only the rider or assigned driver can cancel before a trip starts or chat during an accepted, arriving, or in-progress trip. An assigned driver cannot go offline while their trip is active. Only the rider can rate a completed trip, with an integer rating of 1–5 and integer tip of 0–10000 cents; ratings may be updated as in the existing service.

Fares are server-authoritative: UberX 1840, Comfort 2490, UberXL 2990, Green 1940, Black 3890, and Pet 2140 cents, plus 300 cents per stop. A booking requires a UUID request ID, at most two stops, unique place IDs and coordinates across the entire route, finite latitude/longitude within geographic bounds, and bounded strings matching the existing service. Payment labels cannot contain 12 consecutive digits. Reservation timestamps must be valid ISO-8601 dates after now and at most 30 days ahead. Calendar dates that normalize into another day are rejected.

The canonical normalized booking payload is stored with the room-scoped request ID. An identical retry returns current room state without creating another trip, including after the scheduled time has passed or the trip has ended. A changed payload with that request ID returns 409. New bookings still undergo current-time reservation validation. Notes are limited to the backend's existing 500 characters; the Swift draft may apply its stricter 300-character UI limit. Messages are 1–500 characters after trimming, names at most 80, and cancellation reasons at most 300.
