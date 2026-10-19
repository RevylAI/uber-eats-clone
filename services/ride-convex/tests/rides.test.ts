import { convexTest } from "convex-test";
import { afterEach, describe, expect, test, vi } from "vitest";
import { api } from "../convex/_generated/api";
import schema from "../convex/schema";
import { limits, ttl } from "../convex/validation";

const modules = import.meta.glob("../convex/**/*.ts");
const token = () => crypto.randomUUID().replaceAll("-", "") + crypto.randomUUID().replaceAll("-", "");
const request = () => ({
  requestId: String(crypto.randomUUID()),
  pickup: { id: "pickup", name: "Pickup", address: "1 Main Street", latitude: 30.2, longitude: -97.7 },
  destination: { id: "destination", name: "Destination", address: "2 Main Street", latitude: 30.3, longitude: -97.8 },
  stops: [] as { id: string; name: string; address: string; latitude: number; longitude: number }[],
  service: "uberX", paymentMethod: "Demo Visa •••• 4242", scheduledAt: null as string | null, note: "",
});
const failure = (promise: Promise<unknown>, status: number, message?: string) =>
  expect(promise).rejects.toMatchObject({ data: { status, ...(message ? { message } : {}) } });

async function setup() {
  const t = convexTest({ schema, modules, transactionLimits: true });
  const rider = await t.mutation(api.rides.createRoom, { name: "Alex", token: token() });
  const first = await t.mutation(api.rides.joinRoom, { code: rider.roomCode, name: "Jordan", role: "driver", token: token() });
  const second = await t.mutation(api.rides.joinRoom, { code: rider.roomCode, name: "Sam", role: "driver", token: token() });
  const act = (credential: string, tripID: string, action: string, extra = {}) =>
    t.mutation(api.rides.act, { token: credential, tripID, action: { action, ...extra } });
  const book = (booking = request()) => t.mutation(api.rides.book, { token: rider.token, request: booking });
  const online = (credential = first.token) => t.mutation(api.rides.availability, { token: credential, online: true });
  return { t, rider, first, second, act, book, online };
}

afterEach(() => vi.useRealTimers());

describe("sessions and authorization", () => {
  test("private invitations preserve the rider and create distinct drivers", async () => {
    const { t, rider, first, second } = await setup();
    expect(rider.roomCode).toMatch(/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{16}$/);
    const rejoined = await t.mutation(api.rides.joinRoom, { code: rider.roomCode, role: "rider", name: "Replacement", token: token() });
    expect(rejoined.participantId).toBe(rider.participantId);
    expect(rejoined.name).toBe("Alex");
    expect(first.participantId).not.toBe(second.participantId);
    expect(rejoined.token).not.toBe(rider.token);
    expect(Object.keys(rider).sort()).toEqual(["roomCode", "participantId", "token", "role", "name", "state"].sort());
    expect((await t.query(api.rides.state, { token: rider.token })).revision).toBe(3);
    const retried = await t.mutation(api.rides.joinRoom, { code: rider.roomCode, role: "driver", name: "Changed", token: first.token });
    expect(retried.participantId).toBe(first.participantId);
    expect(retried.name).toBe("Jordan");
    expect(retried.state.revision).toBe(3);
  });

  test("only SHA-256 credential hashes are stored", async () => {
    const { t, rider, first, second } = await setup();
    const tables = await t.run(async ctx => ({
      rooms: await ctx.db.query("rooms").collect(), participants: await ctx.db.query("participants").collect(),
      credentials: await ctx.db.query("credentials").collect(), trips: await ctx.db.query("trips").collect(),
    }));
    for (const person of [rider, first, second]) expect(JSON.stringify(tables)).not.toContain(person.token);
    const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(rider.token));
    const hex = Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, "0")).join("");
    expect(tables.credentials.some(credential => credential.tokenHash === hex)).toBe(true);
  });

  test("invalid credentials fail every public path without leaking their value", async () => {
    const { t, rider } = await setup();
    for (const badToken of ["short", token()]) {
      const operations = [
        t.query(api.rides.state, { token: badToken }),
        t.mutation(api.rides.availability, { token: badToken, online: true }),
        t.mutation(api.rides.book, { token: badToken, request: request() }),
        t.mutation(api.rides.act, { token: badToken, tripID: "missing", action: { action: "cancel" } }),
      ];
      for (const result of await Promise.allSettled(operations)) {
        expect(result.status).toBe("rejected");
        if (result.status === "rejected") {
          expect(result.reason.data.status).toBe(401);
          expect(JSON.stringify(result.reason.data)).not.toContain(badToken);
        }
      }
    }
    await failure(t.mutation(api.rides.createRoom, { token: "short", name: "Alex" }), 401);
    await failure(t.mutation(api.rides.joinRoom, { token: "short", code: rider.roomCode, role: "rider", name: "Alex" }), 401);
  });

  test("tokens cannot change room or role and trip lookup is room scoped", async () => {
    const { t, rider, first, act, book } = await setup();
    const other = await t.mutation(api.rides.createRoom, { name: "Other", token: token() });
    const state = await book();
    const id = state.trips[0].id;
    await failure(t.mutation(api.rides.joinRoom, { code: other.roomCode, role: "rider", name: "Other", token: rider.token }), 409);
    await failure(t.mutation(api.rides.joinRoom, { code: rider.roomCode, role: "driver", name: "Alex", token: rider.token }), 409);
    await failure(t.mutation(api.rides.createRoom, { name: "Alex", token: rider.token }), 409);
    await failure(act(other.token, id, "cancel"), 404);
    await failure(t.mutation(api.rides.book, { token: first.token, request: request() }), 403);
    await failure(t.mutation(api.rides.availability, { token: rider.token, online: true }), 403);
    expect((await t.query(api.rides.state, { token: other.token })).trips).toEqual([]);
  });

  test("every read and write rejects credentials at the 24-hour boundary", async () => {
    vi.useFakeTimers();
    const { t, rider, first, book } = await setup();
    const tripID = (await book()).trips[0].id;
    vi.setSystemTime(Date.now() + ttl);
    await failure(t.query(api.rides.state, { token: rider.token }), 401);
    await failure(t.mutation(api.rides.availability, { token: first.token, online: true }), 401);
    await failure(t.mutation(api.rides.book, { token: rider.token, request: request() }), 401);
    await failure(t.mutation(api.rides.act, { token: rider.token, tripID, action: { action: "cancel" } }), 401);
    await failure(t.mutation(api.rides.joinRoom, { code: rider.roomCode, role: "rider", name: "Alex", token: token() }), 404);
  });

  test("a newly joined credential does not extend the room lifetime", async () => {
    vi.useFakeTimers();
    const { t, rider } = await setup();
    vi.setSystemTime(Date.now() + ttl - 1000);
    const joined = await t.mutation(api.rides.joinRoom, { code: rider.roomCode, role: "rider", name: "Alex", token: token() });
    vi.setSystemTime(Date.now() + 1000);
    await failure(t.query(api.rides.state, { token: joined.token }), 401);
  });

  test("concurrent credential reuse cannot create two rooms", async () => {
    const t = convexTest({ schema, modules, transactionLimits: true });
    const credential = token();
    const results = await Promise.allSettled([
      t.mutation(api.rides.createRoom, { name: "Alex", token: credential }),
      t.mutation(api.rides.createRoom, { name: "Other", token: credential }),
    ]);
    expect(results.filter(result => result.status === "fulfilled")).toHaveLength(1);
    expect(results.find(result => result.status === "rejected")).toMatchObject({ reason: { data: { status: 409 } } });
    expect(await t.run(ctx => ctx.db.query("rooms").collect())).toHaveLength(1);
  });
});

describe("transactions and lifecycle", () => {
  test("a full trip is persisted across independent clients with exact wire fields", async () => {
    const { t, rider, first, second, act, book, online } = await setup();
    const riderClient = t.withIdentity({ subject: "rider-device" });
    const driverClient = t.withIdentity({ subject: "driver-device" });
    await online();
    const booking = request();
    booking.stops = [{ id: "stop", name: "Coffee", address: "3 Main Street", latitude: 31, longitude: -97 }];
    const booked = await book(booking);
    const trip = booked.trips[0];
    expect(trip.fareCents).toBe(2140);
    expect(trip).toMatchObject({ driver: null, scheduledAt: null, cancellationReason: null, rating: null, tipCents: 0, messages: [] });
    expect(Object.keys(trip).sort()).toEqual([
      "id", "riderId", "riderName", "pickup", "destination", "stops", "service", "paymentMethod", "scheduledAt",
      "note", "status", "driver", "fareCents", "createdAt", "updatedAt", "cancellationReason", "rating", "tipCents", "messages",
    ].sort());
    const accepted = await driverClient.mutation(api.rides.act, { token: first.token, tripID: trip.id, action: { action: "accept" } });
    expect(accepted.trips[0].driver).toEqual({ id: first.participantId, name: "Jordan", vehicle: "Toyota Prius", plate: "DEMO 24", rating: 4.98 });
    await act(rider.token, trip.id, "message", { text: " At the door " });
    await act(first.token, trip.id, "message", { text: "On my way" });
    await failure(act(second.token, trip.id, "arrive"), 403);
    await failure(act(first.token, trip.id, "start"), 409);
    await act(first.token, trip.id, "arrive");
    await act(first.token, trip.id, "start");
    await failure(act(rider.token, trip.id, "cancel"), 409);
    await act(first.token, trip.id, "complete");
    const rated = await act(rider.token, trip.id, "rate", { rating: 5, tipCents: 1000 });
    expect(rated.trips[0]).toMatchObject({ status: "completed", rating: 5, tipCents: 1000, fareCents: 2140 });
    const persisted = await riderClient.query(api.rides.state, { token: rider.token });
    expect(persisted).toEqual(rated);
    expect(await driverClient.query(api.rides.state, { token: first.token })).toEqual(rated);
    expect(persisted.trips[0].messages[0]).toMatchObject({ text: "At the door", senderId: rider.participantId, senderName: "Alex" });
    expect(Object.keys(persisted.trips[0].messages[0]).sort()).toEqual(["id", "senderId", "senderName", "text", "createdAt"].sort());
    expect((await book()).trips).toHaveLength(2);
  });

  test("concurrent acceptance assigns exactly one driver atomically", async () => {
    const { t, rider, first, second, act, book, online } = await setup();
    await online(first.token);
    await online(second.token);
    const tripID = (await book()).trips[0].id;
    const results = await Promise.allSettled([act(first.token, tripID, "accept"), act(second.token, tripID, "accept")]);
    expect(results.filter(result => result.status === "fulfilled")).toHaveLength(1);
    const rejected = results.find(result => result.status === "rejected");
    expect(rejected).toMatchObject({ reason: { data: { status: 409 } } });
    const current = await t.query(api.rides.state, { token: rider.token });
    const winner = current.trips[0].driver!.id === first.participantId ? first : second;
    const loser = winner === first ? second : first;
    await failure(act(loser.token, tripID, "message", { text: "Intrusion" }), 403);
    await failure(act(loser.token, tripID, "cancel"), 403);
    await failure(t.mutation(api.rides.availability, { token: winner.token, online: false }), 409);
    await t.mutation(api.rides.availability, { token: loser.token, online: false });
    await act(winner.token, tripID, "cancel", { reason: "Unavailable" });
    expect((await t.mutation(api.rides.availability, { token: winner.token, online: false })).driverOnline).toBe(false);
  });

  test("concurrent booking and idempotency retain a single room trip", async () => {
    const { t, rider, book } = await setup();
    const payload = request();
    const same = await Promise.all([book(payload), book(payload)]);
    expect(same[0]).toEqual(same[1]);
    await failure(book({ ...payload, note: "changed" }), 409, "requestId already used with different payload");
    await failure(book(), 409, "Room already has an active trip");
    expect((await t.query(api.rides.state, { token: rider.token })).trips).toHaveLength(1);
    const another = await t.mutation(api.rides.createRoom, { name: "Other", token: token() });
    await t.mutation(api.rides.book, { token: another.token, request: payload });
  });

  test("concurrent different request IDs cannot create two active trips", async () => {
    const { book } = await setup();
    const results = await Promise.allSettled([book(), book()]);
    expect(results.filter(result => result.status === "fulfilled")).toHaveLength(1);
    expect(results.find(result => result.status === "rejected")).toMatchObject({ reason: { data: { status: 409 } } });
  });

  test("idempotent scheduled bookings still succeed after their scheduled time", async () => {
    vi.useFakeTimers();
    const { book } = await setup();
    const payload = { ...request(), scheduledAt: new Date(Date.now() + 1000).toISOString() };
    const original = await book(payload);
    vi.setSystemTime(Date.now() + 2000);
    expect(await book(payload)).toEqual(original);
  });

  test("acceptance requires an online driver; rider and assigned-driver permissions are enforced", async () => {
    const { rider, first, act, book, online } = await setup();
    const tripID = (await book()).trips[0].id;
    await failure(act(rider.token, tripID, "accept"), 403);
    await failure(act(first.token, tripID, "accept"), 409);
    await failure(act(first.token, tripID, "cancel"), 403);
    await online();
    await act(first.token, tripID, "accept");
    await failure(act(rider.token, tripID, "arrive"), 403);
    await failure(act(rider.token, tripID, "rate", { rating: 5, tipCents: 0 }), 409);
    await act(first.token, tripID, "cancel");
    await failure(act(first.token, tripID, "arrive"), 409);
    await failure(act(rider.token, tripID, "message", { text: "Hi" }), 409);
  });
});

describe("business validation and bounds", () => {
  test.each([
    { requestId: "not-a-uuid" }, { service: "toString" }, { service: "unsupported" }, { paymentMethod: "123456789012" },
    { note: "x".repeat(501) }, { paymentMethod: "" }, { pickup: { ...request().pickup, latitude: 91 } },
    { pickup: { ...request().pickup, longitude: -181 } }, { pickup: { ...request().pickup, name: "x".repeat(201) } },
    { destination: request().pickup }, { destination: { ...request().pickup, id: "other" } },
    { stops: [request().pickup] }, { stops: [request().destination, request().pickup, request().destination] },
    { scheduledAt: "bad" }, { scheduledAt: "2027-99-01T12:00:00Z" }, { scheduledAt: "2027-02-30T12:00:00Z" },
    { scheduledAt: "2027-01-01T24:00:00Z" }, { scheduledAt: "x".repeat(500) },
  ])("rejects invalid booking %#", async invalid => {
    const { book } = await setup();
    await failure(book({ ...request(), ...invalid }), 400);
  });

  test("scheduled dates must be in the next 30 days", async () => {
    vi.useFakeTimers();
    const { book } = await setup();
    for (const delta of [-1, 0, 30 * ttl + 1]) {
      await failure(book({ ...request(), scheduledAt: new Date(Date.now() + delta).toISOString() }), 400);
    }
    expect((await book({ ...request(), scheduledAt: new Date(Date.now() + 30 * ttl).toISOString() })).trips[0].scheduledAt).not.toBeNull();
  });

  test.each(["uberX", "comfort", "uberXL", "green", "black", "pet"])("server computes %s fare", async service => {
    const { book } = await setup();
    const fares = { uberX: 1840, comfort: 2490, uberXL: 2990, green: 1940, black: 3890, pet: 2140 };
    const payload = { ...request(), service, fareCents: 1 };
    expect((await book(payload)).trips[0].fareCents).toBe(fares[service as keyof typeof fares]);
  });

  test("chat, cancellation, ratings and tips enforce limits without partial writes", async () => {
    const { t, rider, first, act, book, online } = await setup();
    const tripID = (await book()).trips[0].id;
    await failure(act(rider.token, tripID, "message", { text: "Hi" }), 409);
    await failure(act(rider.token, tripID, "cancel", { reason: "x".repeat(301) }), 400);
    expect((await t.query(api.rides.state, { token: rider.token })).trips[0].status).toBe("requested");
    await online();
    await act(first.token, tripID, "accept");
    await failure(act(rider.token, tripID, "message", { text: " " }), 400);
    await failure(act(first.token, tripID, "message", { text: "x".repeat(501) }), 400);
    for (let i = 0; i < limits.messages; i++) await act(rider.token, tripID, "message", { text: `Message ${i}` });
    await failure(act(first.token, tripID, "message", { text: "One too many" }), 409);
    await act(first.token, tripID, "arrive");
    await act(first.token, tripID, "start");
    await act(first.token, tripID, "complete");
    await failure(act(first.token, tripID, "rate", { rating: 5, tipCents: 0 }), 403);
    for (const invalid of [{ rating: 0, tipCents: 0 }, { rating: 6, tipCents: 0 }, { rating: 1.5, tipCents: 0 },
      { rating: 5, tipCents: -1 }, { rating: 5, tipCents: 10001 }, { rating: 5, tipCents: 0.5 }]) {
      await failure(act(rider.token, tripID, "rate", invalid), 400);
    }
    expect((await act(rider.token, tripID, "rate", { rating: 1, tipCents: 10000 })).trips[0].tipCents).toBe(10000);
    expect((await act(rider.token, tripID, "rate", { rating: 5, tipCents: 0 })).trips[0].rating).toBe(5);
    await failure(act(rider.token, tripID, "cancel"), 409);
    await failure(act(rider.token, tripID, "message", { text: "Too late" }), 409);
  });

  test("cancelled trips have explicit nullable fields and allow a new booking", async () => {
    const { rider, act, book } = await setup();
    const payload = request();
    const tripID = (await book(payload)).trips[0].id;
    const cancelled = await act(rider.token, tripID, "cancel", { reason: null });
    expect(cancelled.trips[0]).toMatchObject({ status: "cancelled", cancellationReason: null });
    expect(await book(payload)).toEqual(cancelled);
    expect((await book()).trips).toHaveLength(2);
  });

  test("Swift can omit optional booking and action fields", async () => {
    const { t, rider, act } = await setup();
    const { scheduledAt: _, ...payload } = request();
    const booked = await t.mutation(api.rides.book, { token: rider.token, request: payload });
    expect(booked.trips[0].scheduledAt).toBeNull();
    const cancelled = await act(rider.token, booked.trips[0].id, "cancel");
    expect(cancelled.trips[0].cancellationReason).toBeNull();
  });

  test("bounded history preserves idempotency instead of silently deleting records", async () => {
    const { t, rider, act, book } = await setup();
    const original = request();
    const firstID = (await book(original)).trips[0].id;
    await act(rider.token, firstID, "cancel");
    for (let i = 1; i < limits.trips; i++) {
      const booked = await book();
      await act(rider.token, booked.trips[0].id, "cancel");
    }
    await failure(book(), 409, "Room trip limit reached");
    expect((await book(original)).trips).toHaveLength(limits.trips);
    expect((await t.query(api.rides.state, { token: rider.token })).trips).toHaveLength(limits.trips);
  });

  test("participants and credentials are capped without replacing existing identities", async () => {
    const { t, rider } = await setup();
    for (let i = 3; i < limits.participants; i++) {
      await t.mutation(api.rides.joinRoom, { code: rider.roomCode, role: "driver", name: "Driver", token: token() });
    }
    await failure(t.mutation(api.rides.joinRoom, { code: rider.roomCode, role: "driver", name: "Excess", token: token() }), 409);
    for (let i = limits.participants; i < limits.credentials; i++) {
      await t.mutation(api.rides.joinRoom, { code: rider.roomCode, role: "rider", name: "Ignored", token: token() });
    }
    await failure(t.mutation(api.rides.joinRoom, { code: rider.roomCode, role: "rider", name: "Excess", token: token() }), 409);
    expect((await t.query(api.rides.state, { token: rider.token })).trips).toEqual([]);
  });

  test("a maximally populated snapshot stays below transaction and return limits", async () => {
    const { t, rider, book, act } = await setup();
    const original = (await book()).trips[0];
    await act(rider.token, original.id, "cancel");
    const worst = (length: number) => "\u0001".repeat(length);
    await t.run(async ctx => {
      const room = (await ctx.db.query("rooms").withIndex("by_code", q => q.eq("code", rider.roomCode)).unique())!;
      const base = (await ctx.db.query("trips").withIndex("by_room", q => q.eq("roomId", room._id)).first())!;
      const maxPlace = { ...original.pickup, id: worst(100), name: worst(200), address: worst(300) };
      const payload = { ...base.payload, riderName: worst(80), pickup: maxPlace, destination: maxPlace,
        stops: [maxPlace, maxPlace], paymentMethod: worst(80), note: worst(500), cancellationReason: worst(300),
        driver: { id: "d".repeat(32), name: worst(80), vehicle: "Toyota Prius", plate: "DEMO 24", rating: 4.98 },
        messages: Array.from({ length: limits.messages }, () => ({ id: "m".repeat(32), senderId: rider.participantId,
          senderName: worst(80), text: worst(500), createdAt: original.createdAt })) };
      await ctx.db.patch(base._id, { payload });
      for (let i = 1; i < limits.trips; i++) {
        await ctx.db.insert("trips", { roomId: room._id, requestId: String(crypto.randomUUID()), requestPayload: base.requestPayload,
          payload: { ...payload, id: String(i) } });
      }
      await ctx.db.patch(room._id, { tripCount: limits.trips });
    });
    const snapshot = await t.query(api.rides.state, { token: rider.token });
    expect(snapshot.trips).toHaveLength(limits.trips);
    expect(new TextEncoder().encode(JSON.stringify(snapshot)).byteLength).toBeLessThan(8 * 1024 * 1024);
  });

  test("malformed arguments produce safe application errors", async () => {
    const { t, rider } = await setup();
    const unsafe = { token: rider.token, request: null } as unknown as { token: string; request: ReturnType<typeof request> };
    await failure(t.mutation(api.rides.book, unsafe), 400, "Invalid request");
    await failure(t.mutation(api.rides.act, { token: rider.token, tripID: "missing", action: { action: "unsupported" } }), 404);
    await failure(t.mutation(api.rides.createRoom, { name: " ", token: token() }), 400);
    await failure(t.mutation(api.rides.joinRoom, { code: rider.roomCode, role: "admin", name: "Other", token: token() }), 400);
  });
});
