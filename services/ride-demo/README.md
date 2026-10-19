# Shared ride demo server

Dependency-free Node.js 24 HTTP service for the independent ride demo. It is an Uber-inspired public demo, not production dispatch, payment, or authentication software. The room code is an invitation capability; anyone who knows it can join. Keep demo data non-sensitive.

## Run

```sh
node --version # Node 24 or newer
npm start
npm test
```

The service listens on `HOST` (default `0.0.0.0`) and `PORT` (default `8787`). SQLite is stored in `DATA_DIR/rides.sqlite` (`DATA_DIR` defaults to `.data`); WAL is enabled. Persist `/data` when running the Docker image. Rooms expire after 24 hours by default; expiry denies access but does not purge stored data. The demo rate limit is 240 requests per IP per minute, using the direct socket address and deliberately ignoring forwarded headers.

```sh
docker build -t shared-ride-demo .
docker run --rm -p 8787:8787 -v ride-demo-data:/data shared-ride-demo
```

## HTTP and session contract

JSON errors are `{ "error": "..." }`. `POST /v1/rooms` takes `{ "name": "..." }` and returns a `Session` with HTTP 201. `POST /v1/rooms/:code/join` takes `{ "role": "rider"|"driver", "name": "..." }` and returns a session. Joining is public by design: possession of the cryptographically random room code grants invitation access. A rider join recovers the room owner's rider identity; each driver receives a distinct identity. Sessions contain a 32-byte random bearer token; only its SHA-256 hash is stored. Send it only as `Authorization: Bearer <token>`. Tokens in query strings are rejected. No endpoint accepts arbitrary state updates.

Authenticated endpoints return the `State` object, except health and the two session-creation endpoints:

| Method and path | Input | Authorization |
| --- | --- | --- |
| `GET /health` | — | Public; `{ "ok": true }` |
| `GET /v1/state` | — | Any room participant |
| `POST /v1/availability` | `{ "online": boolean }` | Driver |
| `POST /v1/trips` | `{ "requestId": UUID, "pickup": Place, "destination": Place, "stops": Place[], "service": string, "paymentMethod": string, "scheduledAt": string|null, "note": string }` | Room-owner rider |
| `POST /v1/trips/:id/actions` | See actions below | Depends on action |

Trip actions are `{ "action": "accept" }`, `arrive`, `start`, `complete`, `{ "action": "cancel", "reason"?: string }`, `{ "action": "rate", "rating": 1..5, "tipCents": 0..10000 }`, and `{ "action": "message", "text": string }`. Only the room-owning rider or the assigned driver may cancel or chat. A driver can accept only while online; acceptance is atomic, so exactly one driver wins. A driver cannot go offline while assigned to an active trip. Chat is available in accepted, arriving, and in-progress trips; history is capped at 100 messages.

`Place` is `{id,name,address,latitude,longitude}`. `Driver` is `{id,name,vehicle,plate,rating}` and the demo vehicle is Toyota Prius / DEMO 24 / 4.98. `Message` is `{id,senderId,senderName,text,createdAt}`. `Trip` is `{id,riderId,riderName,pickup,destination,stops,service,paymentMethod,scheduledAt,note,status,driver,fareCents,createdAt,updatedAt,cancellationReason,rating,tipCents,messages}`. `State` is `{roomCode,revision,driverOnline,onlineDriverIds,trips}` with newest first. `driverOnline` is aggregate availability; `onlineDriverIds` identifies available driver participants across restarts. Date fields are ISO 8601 strings; nullable fields are explicit. Statuses are `requested`, `accepted`, `arriving`, `in_progress`, `completed`, and `cancelled`.

Services and base fares in cents: `uberX` 1840, `comfort` 2490, `uberXL` 2990, `green` 1940, `black` 3890, and `pet` 2140. Each stop adds 300 cents. Payment method is a bounded demo label; payment processing is not implemented, and long card-number-like strings are rejected. Scheduling accepts a future ISO date through 30 days; missing or null `scheduledAt` means immediate pickup, including clients that omit nil optionals. Drivers may accept and manually advance scheduled rides immediately; the server does not dispatch or wait for scheduled time. Route place IDs and coordinates must be unique. Revisions increment on committed state changes. Requests are limited to 32 KiB and invalid transitions do not mutate state.
