// @vitest-environment node
import { convexTest } from "convex-test";
import { afterEach, describe, expect, test, vi } from "vitest";
import { api } from "../convex/_generated/api";
import type { Id } from "../convex/_generated/dataModel";
import schema from "../convex/schema";
import { limits, ttl } from "../convex/validation";

const modules = import.meta.glob("../convex/**/*.ts");
const password = "dispatch-test-password";
const request = () => ({
  requestId: String(crypto.randomUUID()),
  pickup: { id: "pickup", name: "Pickup", address: "1 Main Street", latitude: 30.2, longitude: -97.7 },
  destination: { id: "destination", name: "Destination", address: "2 Main Street", latitude: 30.3, longitude: -97.8 },
  stops: [] as { id: string; name: string; address: string; latitude: number; longitude: number }[],
  service: "uberX", paymentMethod: "Visa •••• 4242", scheduledAt: null as string | null, note: "",
});
const failure = (promise: Promise<unknown>, status: number, message?: string) =>
  expect(promise).rejects.toMatchObject({ data: { status, ...(message ? { message } : {}) } });

async function setup() {
  const t = convexTest({ schema, modules, transactionLimits: true });
  const serviceArea = `test-${crypto.randomUUID()}`;
  const register = (name: string, role: "rider" | "driver", area = serviceArea) => t.action(api.accounts.signUp, {
    name, role, email: `${crypto.randomUUID()}@example.test`, password, serviceArea: area,
    ...(role === "driver" ? { vehicle: "Honda Accord", plate: "TX 4312" } : {}),
  });
  const rider = await register("Alex", "rider");
  const first = await register("Jordan", "driver");
  const second = await register("Sam", "driver");
  const state = (token = rider.token) => t.query(api.dispatch.state, { token });
  const act = (token: string, tripID: string, action: string, extra = {}) =>
    t.mutation(api.dispatch.act, { token, tripID, action: { action, ...extra } });
  const book = (payload = request(), token = rider.token) => t.mutation(api.dispatch.book, { token, request: payload });
  const online = (token = first.token, value = true) => t.mutation(api.dispatch.availability, { token, online: value });
  const complete = async (tripID: string, token = first.token) => {
    await act(token, tripID, "accept");
    await act(token, tripID, "arrive");
    await act(token, tripID, "start");
    return act(token, tripID, "complete");
  };
  const pointers = () => t.run(async ctx => (await Promise.all([rider, first, second].map(person =>
    ctx.db.get(person.participantId as Id<"users">)))).map(user => user!.activeTripId));
  return { t, serviceArea, register, rider, first, second, state, act, book, online, complete, pointers };
}

afterEach(() => vi.useRealTimers());

describe("account dispatch authorization and isolation", () => {
  test("public signup provides independent database accounts and the existing wire state", async () => {
    const { t, rider, first, state } = await setup();
    for (const person of [rider, first]) {
      expect(person.roomCode).toBe(person.account.id);
      expect(person.participantId).toBe(person.account.id);
      expect(person.token).not.toBe(rider.participantId);
      expect(person.token.length).toBeGreaterThanOrEqual(32);
      expect(person.expiresAt).toBeGreaterThan(Date.now());
      expect(await t.query(api.accounts.profile, { token: person.token })).toEqual(person.account);
      expect(person.state).toEqual({ roomCode: person.participantId, revision: 0, driverOnline: false, onlineDriverIds: [], trips: [] });
    }
    expect(rider.token).not.toBe(first.token);
    expect(rider.participantId).not.toBe(first.participantId);
    expect(Object.keys(await state()).sort()).toEqual(["roomCode", "revision", "driverOnline", "onlineDriverIds", "trips"].sort());
    expect(await t.run(ctx => ctx.db.query("rooms").collect())).toEqual([]);
  });

  test("missing, forged, revoked and expired sessions reject every dispatch path safely", async () => {
    const { t, rider, first, book } = await setup();
    const tripID = (await book()).trips[0].id;
    const operations = (token: string) => [
      t.query(api.dispatch.state, { token }),
      t.mutation(api.dispatch.availability, { token, online: true }),
      t.mutation(api.dispatch.book, { token, request: request() }),
      t.mutation(api.dispatch.act, { token, tripID, action: { action: "cancel" } }),
    ];
    await t.mutation(api.accounts.signOut, { token: first.token });
    await t.run(async ctx => {
      const session = (await ctx.db.query("sessions").collect()).find(row => row.userId === rider.participantId)!;
      await ctx.db.patch(session._id, { expiresAt: Date.now() });
    });
    for (const token of ["short", `user.${crypto.randomUUID().repeat(2)}`, first.token, rider.token]) {
      for (const result of await Promise.allSettled(operations(token))) {
        expect(result.status).toBe("rejected");
        if (result.status === "rejected") {
          expect(result.reason.data.status).toBe(401);
          expect(JSON.stringify(result.reason.data)).not.toContain(token);
        }
      }
    }
  });

  test("riders see only their trips and drivers only area offers and their own assigned history", async () => {
    const { t, register, rider, first, second, state, act, book, online, complete } = await setup();
    const other = await register("Other rider", "rider");
    const remoteRider = await register("Remote rider", "rider", "isolated-remote");
    const remoteDriver = await register("Remote driver", "driver", "isolated-remote");
    await online();
    await online(remoteDriver.token);
    const ownID = (await book()).trips[0].id;
    const otherID = (await book(request(), other.token)).trips[0].id;
    const remoteID = (await book(request(), remoteRider.token)).trips[0].id;
    expect((await state()).trips.map(trip => trip.id)).toEqual([ownID]);
    expect((await state(first.token)).trips.map(trip => trip.id).sort()).toEqual([ownID, otherID].sort());
    expect((await state(remoteDriver.token)).trips.map(trip => trip.id)).toEqual([remoteID]);
    expect((await state()).onlineDriverIds).toEqual([first.participantId]);
    expect((await state(remoteRider.token)).onlineDriverIds).toEqual([remoteDriver.participantId]);
    await failure(act(other.token, ownID, "cancel"), 404);
    await failure(act(remoteDriver.token, ownID, "accept"), 404);
    await act(first.token, ownID, "accept");
    await act(rider.token, ownID, "message", { text: "Private door code" });
    const unassigned = await state(second.token);
    expect(unassigned.trips.map(trip => trip.id)).toEqual([otherID]);
    expect(JSON.stringify(unassigned)).not.toContain("Private door code");
    for (const action of ["arrive", "start", "complete", "cancel", "message", "rate"]) {
      await failure(act(second.token, ownID, action, { text: "Intrusion", rating: 5, tipCents: 0 }), 403);
    }
    await act(first.token, ownID, "cancel");
    await complete(otherID);
    expect((await state(first.token)).trips.map(trip => trip.id).sort()).toEqual([ownID, otherID].sort());
    expect((await state(second.token)).trips).toEqual([]);
    expect((await state(other.token)).trips.map(trip => trip.id)).toEqual([otherID]);
    expect((await t.query(api.accounts.resume, { token: rider.token })).state).toEqual(await state());
  });

  test("client-supplied roles, names, identity, area and driver profile cannot spoof database identity", async () => {
    const { t, rider, first, state, act, online } = await setup();
    const spoof = { role: "driver", name: "Forged", participantId: first.participantId, serviceArea: "elsewhere" };
    await failure(t.mutation(api.dispatch.availability, { token: rider.token, online: true, ...spoof }), 403);
    const driverBooking = { token: first.token, request: request(), role: "rider" };
    await failure(t.mutation(api.dispatch.book, driverBooking), 403);
    const booking = { token: rider.token, request: { ...request(), riderId: first.participantId, riderName: "Forged", fareCents: 1 }, ...spoof };
    const trip = (await t.mutation(api.dispatch.book, booking)).trips[0];
    expect(trip).toMatchObject({ riderId: rider.participantId, riderName: "Alex", fareCents: 1840 });
    await failure(act(rider.token, trip.id, "accept", spoof), 403);
    await online();
    await act(first.token, trip.id, "accept", { role: "driver", name: "Forged", vehicle: "Fake", plate: "FAKE", rating: 5 });
    expect((await state()).trips[0].driver).toEqual({ id: first.participantId, name: "Jordan", vehicle: "Honda Accord", plate: "TX 4312", rating: 0 });
    await act(first.token, trip.id, "message", { text: "Hello", senderId: rider.participantId, senderName: "Forged" });
    expect((await state()).trips[0].messages[0]).toMatchObject({ senderId: first.participantId, senderName: "Jordan" });
  });

  test("area-wide revisions order other users' discovery updates without changing on retries", async () => {
    const { register, rider, first, second, state, book, online, act } = await setup();
    expect((await state()).revision).toBe(0);
    await online();
    expect((await state()).revision).toBe(1);
    expect((await state(first.token)).revision).toBe(1);
    const payload = request();
    const booked = await book(payload);
    expect(booked.revision).toBe(2);
    expect((await state(second.token)).revision).toBe(2);
    await online(second.token);
    expect((await state()).revision).toBe(3);
    expect((await book(payload)).revision).toBe(3);
    const remote = await register("Remote driver", "driver", "isolated-revision-area");
    await online(remote.token);
    expect((await state(remote.token)).revision).toBe(1);
    expect((await state()).revision).toBe(3);
    await act(first.token, booked.trips[0].id, "accept");
    expect((await state()).revision).toBe(4);
    expect((await state(second.token)).revision).toBe(4);
    await act(rider.token, booked.trips[0].id, "cancel");
    expect((await state(first.token)).revision).toBe(5);
  });
});

describe("transactional assignment and durable requests", () => {
  test("concurrent drivers accept a trip exactly once and release both pointers on cancellation", async () => {
    const { rider, first, second, state, act, book, online, pointers } = await setup();
    await online();
    await online(second.token);
    const id = (await book()).trips[0].id;
    const results = await Promise.allSettled([act(first.token, id, "accept"), act(second.token, id, "accept")]);
    expect(results.filter(result => result.status === "fulfilled")).toHaveLength(1);
    expect(results.find(result => result.status === "rejected")).toMatchObject({ reason: { data: { status: 409 } } });
    const assigned = (await state()).trips[0].driver!;
    const winner = assigned.id === first.participantId ? first : second;
    const loser = winner === first ? second : first;
    const currentPointers = await pointers();
    expect(currentPointers.filter(Boolean)).toHaveLength(2);
    expect(currentPointers[0]).toBe(currentPointers[winner === first ? 1 : 2]);
    await failure(online(winner.token, false), 409);
    await failure(act(loser.token, id, "cancel"), 403);
    await online(loser.token, false);
    await act(rider.token, id, "cancel");
    expect(await pointers()).toEqual([null, null, null]);
    await online(winner.token, false);
    expect((await state()).driverOnline).toBe(false);
  });

  test("one driver cannot concurrently accept two different riders' trips", async () => {
    const { t, register, rider, first, act, book, online, state } = await setup();
    const other = await register("Other", "rider");
    await online();
    const ids = [(await book()).trips[0].id, (await book(request(), other.token)).trips[0].id];
    const results = await Promise.allSettled(ids.map(id => act(first.token, id, "accept")));
    expect(results.filter(result => result.status === "fulfilled")).toHaveLength(1);
    expect(results.find(result => result.status === "rejected")).toMatchObject({ reason: { data: { status: 409 } } });
    const rows = await t.run(ctx => ctx.db.query("dispatchTrips").withIndex("by_driver", q => q.eq("driverId", first.participantId as Id<"users">)).collect());
    expect(rows).toHaveLength(1);
    const user = await t.run(ctx => ctx.db.get(first.participantId as Id<"users">));
    expect(user!.activeTripId).toBe(rows[0]._id);
    const winner = rows[0].payload.id;
    const losing = ids.find(id => id !== winner)!;
    await act(first.token, winner, "cancel");
    await act(first.token, losing, "accept");
    expect((await state(first.token)).trips.find(trip => trip.id === losing)!.status).toBe("accepted");
    expect((await state(rider.token)).trips).toHaveLength(1);
  });

  test("concurrent duplicate requests are idempotent and distinct requests leave one rider active", async () => {
    const { t, register, rider, book } = await setup();
    const payload = request();
    const results = await Promise.all([book(payload), book(payload)]);
    expect(results[0]).toEqual(results[1]);
    await failure(book({ ...payload, note: "changed" }), 409);
    await failure(book(), 409);
    const other = await register("Other", "rider");
    const races = await Promise.allSettled([book(request(), other.token), book(request(), other.token)]);
    expect(races.filter(result => result.status === "fulfilled")).toHaveLength(1);
    expect(races.find(result => result.status === "rejected")).toMatchObject({ reason: { data: { status: 409 } } });
    const rows = await t.run(ctx => ctx.db.query("dispatchTrips").withIndex("by_rider", q => q.eq("riderId", rider.participantId as Id<"users">)).collect());
    expect(rows).toHaveLength(1);
  });

  test("request UUIDs remain durable beyond the history window without a lifetime cap", async () => {
    const { t, register, rider, book, act, state } = await setup();
    const original = request();
    const firstID = (await book(original)).trips[0].id;
    await act(rider.token, firstID, "cancel");
    for (let i = 0; i < 24; i++) {
      const id = (await book()).trips[0].id;
      await act(rider.token, id, "cancel");
    }
    const current = await state();
    expect(current.trips).toHaveLength(20);
    expect(current.trips.some(trip => trip.id === firstID)).toBe(false);
    expect(await book(original)).toEqual(current);
    await failure(book({ ...original, paymentMethod: "Cash" }), 409);
    const active = (await book()).trips[0];
    expect(active.status).toBe("requested");
    expect(await book(original)).toEqual(await state());
    const other = await register("Other", "rider");
    expect((await book(original, other.token)).trips[0].riderId).toBe(other.participantId);
    expect(await t.run(ctx => ctx.db.query("dispatchTrips").withIndex("by_rider", q => q.eq("riderId", rider.participantId as Id<"users">)).collect())).toHaveLength(26);
  });

  test("scheduled request retries succeed after their time but changed/new past bookings fail", async () => {
    const { book } = await setup();
    vi.useFakeTimers();
    const original = { ...request(), scheduledAt: new Date(Date.now() + 1000).toISOString() };
    const snapshot = await book(original);
    vi.setSystemTime(Date.now() + 2000);
    expect(await book(original)).toEqual(snapshot);
    await failure(book({ ...original, note: "changed" }), 409);
    await failure(book({ ...original, requestId: crypto.randomUUID() }), 400);
  });

  test("a driver accepting an older offer retains it within twenty total history rows", async () => {
    const { register, first, rider, book, online, complete, act, state } = await setup();
    const other = await register("Another rider", "rider");
    const oldID = (await book()).trips[0].id;
    await online();
    for (let i = 0; i < 22; i++) await complete((await book(request(), other.token)).trips[0].id);
    expect((await state(first.token)).trips).toHaveLength(21);
    await act(first.token, oldID, "accept");
    const snapshot = await state(first.token);
    expect(snapshot.trips).toHaveLength(20);
    expect(snapshot.trips.filter(trip => trip.status === "completed")).toHaveLength(19);
    expect(snapshot.trips.find(trip => trip.id === oldID)!.status).toBe("accepted");
    await act(rider.token, oldID, "cancel");
    expect((await state(first.token)).trips).toHaveLength(20);
  });
});

describe("dispatch lifecycle and business validation", () => {
  test("independent clients persist the complete existing trip and message wire formats", async () => {
    const { t, rider, first, state, act, book, online, pointers } = await setup();
    await online();
    const payload = request();
    payload.stops = [{ id: "stop", name: "Coffee", address: "3 Main Street", latitude: 31, longitude: -97 }];
    const booked = await book(payload);
    const trip = booked.trips[0];
    expect(trip.fareCents).toBe(2140);
    expect(trip).toMatchObject({ driver: null, scheduledAt: null, cancellationReason: null, rating: null, tipCents: 0, messages: [] });
    expect(Object.keys(trip).sort()).toEqual([
      "id", "riderId", "riderName", "pickup", "destination", "stops", "service", "paymentMethod", "scheduledAt",
      "note", "status", "driver", "fareCents", "createdAt", "updatedAt", "cancellationReason", "rating", "tipCents", "messages",
    ].sort());
    const driverClient = t.withIdentity({ subject: "independent-driver-device" });
    await driverClient.mutation(api.dispatch.act, { token: first.token, tripID: trip.id, action: { action: "accept" } });
    await act(rider.token, trip.id, "message", { text: " At the door " });
    await act(first.token, trip.id, "message", { text: "On my way" });
    await failure(act(first.token, trip.id, "start"), 409);
    await failure(act(rider.token, trip.id, "arrive"), 403);
    await act(first.token, trip.id, "arrive");
    await act(first.token, trip.id, "start");
    await failure(act(rider.token, trip.id, "cancel"), 409);
    await act(first.token, trip.id, "complete");
    expect(await pointers()).toEqual([null, null, null]);
    const rated = await act(rider.token, trip.id, "rate", { rating: 5, tipCents: 1000 });
    expect(rated.trips[0]).toMatchObject({ status: "completed", rating: 5, tipCents: 1000, fareCents: 2140 });
    expect(await t.withIdentity({ subject: "independent-rider-device" }).query(api.dispatch.state, { token: rider.token })).toEqual(rated);
    expect((await state(first.token)).trips).toEqual(rated.trips);
    expect(rated.trips[0].messages[0]).toMatchObject({ text: "At the door", senderId: rider.participantId, senderName: "Alex" });
    expect(Object.keys(rated.trips[0].messages[0]).sort()).toEqual(["id", "senderId", "senderName", "text", "createdAt"].sort());
    const next = (await book()).trips[0].id;
    await act(rider.token, trip.id, "rate", { rating: 4, tipCents: 0 });
    expect((await pointers())[0]).not.toBeNull();
    await failure(book(), 409);
    await act(rider.token, next, "cancel");
  });

  test("acceptance requires online availability and lifecycle changes reject partial writes", async () => {
    const { rider, first, state, act, book, online } = await setup();
    const id = (await book()).trips[0].id;
    await failure(act(first.token, id, "accept"), 409);
    await failure(act(first.token, id, "cancel"), 403);
    await failure(act(rider.token, id, "message", { text: "Hello" }), 409);
    await failure(act(rider.token, id, "cancel", { reason: "x".repeat(301) }), 400);
    expect((await state()).trips[0].status).toBe("requested");
    await online();
    await act(first.token, id, "accept");
    await failure(act(first.token, id, "complete"), 409);
    await failure(act(rider.token, id, "rate", { rating: 5, tipCents: 0 }), 409);
    await act(first.token, id, "cancel", { reason: " Unavailable " });
    expect((await state()).trips[0].cancellationReason).toBe("Unavailable");
    await failure(act(first.token, id, "arrive"), 409);
    await failure(act(rider.token, id, "message", { text: "Hi" }), 409);
    await online(first.token, false);
    expect((await book()).trips).toHaveLength(2);
  });

  test("chat limits, ratings and tips match rides without partial updates", async () => {
    const { rider, first, act, book, online, state } = await setup();
    const id = (await book()).trips[0].id;
    await online();
    await act(first.token, id, "accept");
    await failure(act(rider.token, id, "message", { text: " " }), 400);
    await failure(act(first.token, id, "message", { text: "x".repeat(501) }), 400);
    for (let i = 0; i < limits.messages; i++) await act(rider.token, id, "message", { text: `Message ${i}` });
    await failure(act(first.token, id, "message", { text: "One too many" }), 409);
    await act(first.token, id, "arrive");
    await act(first.token, id, "start");
    await act(first.token, id, "complete");
    await failure(act(first.token, id, "rate", { rating: 5, tipCents: 0 }), 403);
    for (const invalid of [
      { rating: 0, tipCents: 0 }, { rating: 6, tipCents: 0 }, { rating: 1.5, tipCents: 0 },
      { rating: null, tipCents: 0 }, { rating: "5", tipCents: 0 }, { rating: 5, tipCents: -1 },
      { rating: 5, tipCents: 10001 }, { rating: 5, tipCents: 0.5 }, { rating: 5, tipCents: null },
    ]) await failure(act(rider.token, id, "rate", invalid), 400);
    expect((await state()).trips[0]).toMatchObject({ rating: null, tipCents: 0 });
    expect((await act(rider.token, id, "rate", { rating: 1, tipCents: 10000 })).trips[0].tipCents).toBe(10000);
    expect((await act(rider.token, id, "rate", { rating: 5, tipCents: 0 })).trips[0].rating).toBe(5);
    await failure(act(rider.token, id, "cancel"), 409);
    await failure(act(first.token, id, "message", { text: "Too late" }), 409);
  });

  test.each(["uberX", "comfort", "uberXL", "green", "black", "pet"])("server computes %s fares with two stops", async service => {
    const { book } = await setup();
    const fares = { uberX: 1840, comfort: 2490, uberXL: 2990, green: 1940, black: 3890, pet: 2140 };
    const payload = { ...request(), service, fareCents: 1, stops: [
      { id: "a", name: "A", address: "A", latitude: 31, longitude: -97 },
      { id: "b", name: "B", address: "B", latitude: 32, longitude: -98 },
    ] };
    expect((await book(payload)).trips[0].fareCents).toBe(fares[service as keyof typeof fares] + 600);
  });

  test.each([
    { requestId: "bad" }, { service: "toString" }, { service: "unsupported" }, { paymentMethod: "123456789012" },
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

  test("scheduled dates use the same thirty-day bounds and omitted fields stay nullable", async () => {
    const { t, rider, book, act, state } = await setup();
    vi.useFakeTimers();
    for (const delta of [-1, 0, 30 * ttl + 1]) {
      await failure(book({ ...request(), scheduledAt: new Date(Date.now() + delta).toISOString() }), 400);
    }
    const future = (await book({ ...request(), scheduledAt: new Date(Date.now() + 30 * ttl).toISOString() })).trips[0];
    await act(rider.token, future.id, "cancel");
    const { scheduledAt: _, ...payload } = request();
    const trip = (await t.mutation(api.dispatch.book, { token: rider.token, request: payload })).trips[0];
    expect(trip.scheduledAt).toBeNull();
    await act(rider.token, trip.id, "cancel");
    expect((await state()).trips[0].cancellationReason).toBeNull();
  });

  test("malformed arguments return safe application errors across every path", async () => {
    const { t, rider, first, book, act, state } = await setup();
    await failure(t.query(api.dispatch.state, {} as never), 401);
    await failure(t.mutation(api.dispatch.availability, {} as never), 401);
    await failure(t.mutation(api.dispatch.book, {} as never), 401);
    await failure(t.mutation(api.dispatch.act, {} as never), 401);
    await failure(t.mutation(api.dispatch.book, { token: rider.token, request: null } as never), 400);
    for (const online of [null, "true", 1]) await failure(t.mutation(api.dispatch.availability, { token: first.token, online } as never), 400);
    const id = (await book()).trips[0].id;
    for (const action of [null, [], "cancel", { action: null }, { action: "x".repeat(21) }]) {
      await failure(t.mutation(api.dispatch.act, { token: rider.token, tripID: id, action } as never), 400);
    }
    await failure(t.mutation(api.dispatch.act, { token: rider.token, tripID: null, action: { action: "cancel" } } as never), 400);
    await failure(act(rider.token, id, "unsupported"), 400);
    await failure(act(rider.token, "missing", "cancel"), 404);
    expect((await state()).trips[0].status).toBe("requested");
  });
});

describe("bounded indexed snapshots", () => {
  test("area offers and online drivers remain bounded even when an area grows", async () => {
    const { t, rider, first, serviceArea, register, online, book, state } = await setup();
    await book();
    await t.run(async ctx => {
      const base = (await ctx.db.query("dispatchTrips").withIndex("by_rider", q => q.eq("riderId", rider.participantId as Id<"users">)).first())!;
      const { _id: _, _creationTime: __, ...driver } = (await ctx.db.get(first.participantId as Id<"users">))!;
      for (let i = 0; i < 40; i++) {
        await ctx.db.insert("users", { ...driver, email: `driver-${i}@example.test`, online: true });
        await ctx.db.insert("dispatchTrips", { riderId: base.riderId, driverId: null, serviceArea, status: "requested",
          requestId: crypto.randomUUID(), requestPayload: base.requestPayload, payload: { ...base.payload, id: crypto.randomUUID() } });
      }
    });
    const snapshot = await state(first.token);
    expect(snapshot.trips).toHaveLength(20);
    expect(snapshot.trips.every(trip => trip.status === "requested" && trip.driver === null && trip.messages.length === 0)).toBe(true);
    expect(snapshot.onlineDriverIds).toHaveLength(limits.participants);
    expect(snapshot.driverOnline).toBe(true);
    expect((await state()).trips).toHaveLength(20);
    const late = await register("Late driver", "driver");
    await online(late.token);
    const lateState = await state(late.token);
    expect(lateState.onlineDriverIds).toHaveLength(limits.participants);
    expect(lateState.onlineDriverIds).toContain(late.participantId);
    await online(late.token, false);
    expect((await state(late.token)).onlineDriverIds).not.toContain(late.participantId);
  });

  test("maximal history, old active trip and offers stay below transaction and snapshot limits", async () => {
    const { t, rider, first, serviceArea, book, state } = await setup();
    const original = (await book()).trips[0];
    const worst = (length: number) => "\u0001".repeat(length);
    await t.run(async ctx => {
      const base = (await ctx.db.query("dispatchTrips").withIndex("by_rider", q => q.eq("riderId", rider.participantId as Id<"users">)).first())!;
      const driverId = first.participantId as Id<"users">;
      const maxPlace = { ...original.pickup, id: worst(100), name: worst(200), address: worst(300) };
      const payload = { ...base.payload, riderName: worst(80), pickup: maxPlace, destination: maxPlace,
        stops: [maxPlace, maxPlace], paymentMethod: worst(80), note: worst(500), cancellationReason: worst(300),
        driver: { id: first.participantId, name: worst(80), vehicle: worst(100), plate: worst(20), rating: 0 },
        messages: Array.from({ length: limits.messages }, () => ({ id: "m".repeat(32), senderId: rider.participantId,
          senderName: worst(80), text: worst(500), createdAt: original.createdAt })) };
      await ctx.db.patch(base._id, { driverId, status: "accepted", payload: { ...payload, status: "accepted" } });
      await ctx.db.patch(driverId, { activeTripId: base._id, online: true });
      for (let i = 0; i < 20; i++) {
        await ctx.db.insert("dispatchTrips", { riderId: base.riderId, driverId, serviceArea, status: "completed",
          requestId: crypto.randomUUID(), requestPayload: base.requestPayload, payload: { ...payload, status: "completed", id: String(i) } });
        await ctx.db.insert("dispatchTrips", { riderId: base.riderId, driverId: null, serviceArea, status: "requested",
          requestId: crypto.randomUUID(), requestPayload: base.requestPayload,
          payload: { ...payload, status: "requested", id: `offer-${i}`, driver: null, messages: [], cancellationReason: null } });
      }
    });
    const snapshot = await state(first.token);
    expect(snapshot.trips.filter(trip => trip.driver?.id === first.participantId)).toHaveLength(20);
    expect(snapshot.trips.some(trip => trip.id === original.id && trip.status === "accepted")).toBe(true);
    expect(snapshot.trips.filter(trip => trip.status === "requested")).toHaveLength(20);
    expect(new TextEncoder().encode(JSON.stringify(snapshot)).byteLength).toBeLessThan(8 * 1024 * 1024);
  });
});
