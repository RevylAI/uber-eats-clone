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

Tests use `convex-test` and Vitest's edge runtime, with transaction limits enabled. They do not require a Convex account, local deployment, environment variables, or network access after installation. Concurrent test calls exercise the mock backend's serialized transactions; production conflict retries and live subscriptions still require integration verification against a deployment.

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

## Public API

All functions live in `convex/rides.ts`. Function paths are `rides:createRoom`, `rides:joinRoom`, `rides:state`, `rides:availability`, `rides:book`, and `rides:act`.

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

## Credentials and privacy boundary

The client must generate a fresh credential from cryptographically secure random bytes before creating or joining a room. Accepted credentials are 32–256 characters, used verbatim without trimming, and hashed with server-side SHA-256. Application tables persist only the hash and a participant reference. No application function logs credentials or stores plaintext credentials in documents or errors. Credentials are necessarily sent as Convex function arguments over TLS; handle client transport, platform access, and observability as sensitive infrastructure. Do not place tokens in URLs, logs, analytics, or repository files.

Rooms expire 24 hours after creation. Every credential expires no later than its room, and joining never extends the lifetime. Expired documents are inaccessible through the public functions but are not automatically deleted; expiry is an authorization boundary, not a retention/deletion policy.

Invitations are private, case-sensitive, 16-character capabilities using `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (80 bits). They are derived from the client's cryptographically random token using domain-separated SHA-256, mapped without modulo bias into the 32-character alphabet, and checked for collisions inside the transaction. The invitation digest is independent of the stored credential digest; the token cannot be recovered from the invitation. This relies on the required secure client token generation, not on ordinary JavaScript randomness. Non-secret participant/trip/message identifiers use Convex's strong seeded PRNG. Sharing an invitation permits someone to join as the existing rider or as a new driver and read that room's full trip history. A rider join preserves the original rider's identity and name; drivers receive separate identities. Reusing a token is allowed only for an idempotent join to the same room and role. Tokens cannot be reassigned across rooms or roles.

This is private-capability demo authentication, **not production user authentication**. There is no verified user identity, membership approval, per-IP rate limiter, payment processing, or abuse-prevention service. Production use needs an authenticated identity and invitation-management policy, abuse protection at ingress, and an explicit data-retention policy. The public functions offer no administrative database access.

## Business rules and bounded reads

Each room has one rider, at most 31 distinct drivers, at most 128 credentials, and at most 20 lifetime trips. Each trip has at most 100 messages. Reaching a cap returns 409 rather than deleting history, invalidating old credentials, or weakening request-id idempotency. Start a new room for another demo. These caps keep full-room snapshots bounded even with maximum-length Unicode strings and full chat histories; there is no hidden partial-history pagination.

All state changes are single Convex transactions. The room's active-trip pointer prevents concurrent bookings; acceptance reads and writes the same trip atomically, so only one online driver can win. Only the assigned driver can arrive, start, or complete. Only the rider or assigned driver can cancel before a trip starts or chat during an accepted, arriving, or in-progress trip. An assigned driver cannot go offline while their trip is active. Only the rider can rate a completed trip, with an integer rating of 1–5 and integer tip of 0–10000 cents; ratings may be updated as in the existing service.

Fares are server-authoritative: UberX 1840, Comfort 2490, UberXL 2990, Green 1940, Black 3890, and Pet 2140 cents, plus 300 cents per stop. A booking requires a UUID request ID, at most two stops, unique place IDs and coordinates across the entire route, finite latitude/longitude within geographic bounds, and bounded strings matching the existing service. Payment labels cannot contain 12 consecutive digits. Reservation timestamps must be valid ISO-8601 dates after now and at most 30 days ahead. Calendar dates that normalize into another day are rejected.

The canonical normalized booking payload is stored with the room-scoped request ID. An identical retry returns current room state without creating another trip, including after the scheduled time has passed or the trip has ended. A changed payload with that request ID returns 409. New bookings still undergo current-time reservation validation. Notes are limited to the backend's existing 500 characters; the Swift draft may apply its stricter 300-character UI limit. Messages are 1–500 characters after trimming, names at most 80, and cancellation reasons at most 300.
