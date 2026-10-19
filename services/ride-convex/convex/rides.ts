import { v } from "convex/values";
import { mutation, query, type MutationCtx, type QueryCtx } from "./_generated/server";
import type { Doc } from "./_generated/dataModel";
import { alphabet, booking, fail, fares, invitation, limits, object, randomId, text, tokenHash, ttl, validSchedule } from "./validation";

type Reader = QueryCtx | MutationCtx;

async function roomState(ctx: Reader, room: Doc<"rooms">) {
  const people = await ctx.db.query("participants").withIndex("by_room", q => q.eq("roomId", room._id)).take(limits.participants);
  const trips = await ctx.db.query("trips").withIndex("by_room", q => q.eq("roomId", room._id)).order("desc").take(limits.trips);
  const onlineDriverIds = people.filter(person => person.role === "driver" && person.online).map(person => person.id);
  return { roomCode: room.code, revision: room.revision, driverOnline: onlineDriverIds.length > 0,
    onlineDriverIds, trips: trips.map(trip => trip.payload) };
}

function checkExpiry(room: Doc<"rooms"> | null): asserts room is Doc<"rooms"> {
  if (!room || Date.now() >= room.expiresAt) fail(404, "Room expired");
}

async function authenticate(ctx: Reader, token: unknown) {
  const hash = await tokenHash(token);
  const credential = await ctx.db.query("credentials").withIndex("by_hash", q => q.eq("tokenHash", hash)).unique();
  if (!credential || Date.now() >= credential.expiresAt) fail(401, "Invalid or expired bearer token");
  const participant = await ctx.db.get(credential.participantId);
  if (!participant) fail(401, "Invalid bearer token");
  const room = await ctx.db.get(participant.roomId);
  checkExpiry(room);
  return { participant, room };
}

async function changed(ctx: MutationCtx, room: Doc<"rooms">) {
  await ctx.db.patch(room._id, { revision: room.revision + 1 });
  return roomState(ctx, { ...room, revision: room.revision + 1 });
}

async function session(ctx: Reader, room: Doc<"rooms">, participant: Doc<"participants">, token: string) {
  return { roomCode: room.code, participantId: participant.id, token, role: participant.role,
    name: participant.name, state: await roomState(ctx, room) };
}

export const createRoom = mutation({
  args: v.any(),
  handler: async (ctx, args: { name: string; token: string }) => {
    const input = object(args, "arguments");
    const hash = await tokenHash(input.token);
    const name = text(input.name, 80, "name");
    const existing = await ctx.db.query("credentials").withIndex("by_hash", q => q.eq("tokenHash", hash)).unique();
    if (existing) fail(409, "Credential already in use");
    let code = "";
    for (let attempt = 0; attempt < 20; attempt++) {
      const candidate = await invitation(args.token, attempt);
      if (!await ctx.db.query("rooms").withIndex("by_code", q => q.eq("code", candidate)).unique()) {
        code = candidate;
        break;
      }
    }
    if (!code) fail(503, "Could not allocate room");
    const riderId = randomId();
    const expiresAt = Date.now() + ttl;
    const roomId = await ctx.db.insert("rooms", {
      code, riderId, expiresAt, revision: 0, activeTripId: null, tripCount: 0, participantCount: 1, credentialCount: 1,
    });
    const participantId = await ctx.db.insert("participants", { roomId, id: riderId, role: "rider", name, online: false });
    await ctx.db.insert("credentials", { tokenHash: hash, participantId, expiresAt });
    return session(ctx, (await ctx.db.get(roomId))!, (await ctx.db.get(participantId))!, args.token);
  },
});

export const joinRoom = mutation({
  args: v.any(),
  handler: async (ctx, args: { code: string; role: string; name: string; token: string }) => {
    const input = object(args, "arguments");
    const hash = await tokenHash(input.token);
    const code = text(input.code, 16, "code");
    if (code.length !== 16 || ![...code].every(char => alphabet.includes(char))) fail(404, "Room not found");
    const room = await ctx.db.query("rooms").withIndex("by_code", q => q.eq("code", code)).unique();
    checkExpiry(room);
    const name = text(input.name, 80, "name");
    const role = input.role;
    if (role !== "rider" && role !== "driver") fail(400, "Invalid role");
    const existing = await ctx.db.query("credentials").withIndex("by_hash", q => q.eq("tokenHash", hash)).unique();
    if (existing) {
      const auth = await authenticate(ctx, input.token);
      if (auth.room._id !== room._id || auth.participant.role !== role) fail(409, "Credential already in use");
      return session(ctx, room, auth.participant, args.token);
    }
    if (room.credentialCount >= limits.credentials) fail(409, "Room credential limit reached");
    if (role === "driver" && room.participantCount >= limits.participants) fail(409, "Room participant limit reached");
    let participantId;
    if (role === "rider") {
      const rider = await ctx.db.query("participants").withIndex("by_room_id", q => q.eq("roomId", room._id).eq("id", room.riderId)).unique();
      if (!rider || rider.role !== "rider") fail(404, "Rider not found");
      participantId = rider._id;
    } else {
      participantId = await ctx.db.insert("participants", { roomId: room._id, id: randomId(), role, name, online: false });
    }
    await ctx.db.insert("credentials", { tokenHash: hash, participantId, expiresAt: room.expiresAt });
    await ctx.db.patch(room._id, { credentialCount: room.credentialCount + 1,
      participantCount: room.participantCount + (role === "driver" ? 1 : 0), revision: room.revision + 1 });
    return session(ctx, { ...room, revision: room.revision + 1 }, (await ctx.db.get(participantId))!, args.token);
  },
});

export const state = query({
  args: v.any(),
  handler: async (ctx, args: { token: string }) => {
    const { room } = await authenticate(ctx, object(args, "arguments").token);
    return roomState(ctx, room);
  },
});

export const availability = mutation({
  args: v.any(),
  handler: async (ctx, args: { token: string; online: boolean }) => {
    const input = object(args, "arguments");
    const { participant, room } = await authenticate(ctx, input.token);
    if (participant.role !== "driver") fail(403, "Driver role required");
    if (typeof input.online !== "boolean") fail(400, "online must be boolean");
    if (!input.online && room.activeTripId) {
      const active = await ctx.db.get(room.activeTripId);
      if (active?.payload.driver?.id === participant.id) fail(409, "Cannot go offline during an active trip");
    }
    await ctx.db.patch(participant._id, { online: input.online });
    return changed(ctx, room);
  },
});

type Place = { id: string; name: string; address: string; latitude: number; longitude: number };
type Request = { requestId: string; pickup: Place; destination: Place; stops: Place[]; service: string;
  paymentMethod: string; scheduledAt?: string | null; note: string };

export const book = mutation({
  args: v.any(),
  handler: async (ctx, args: { token: string; request: Request }) => {
    const input = object(args, "arguments");
    const { participant, room } = await authenticate(ctx, input.token);
    if (participant.role !== "rider" || participant.id !== room.riderId) fail(403, "Room owner rider required");
    const { requestId, payload } = booking(input.request);
    const requestPayload = JSON.stringify(payload);
    const previous = await ctx.db.query("trips").withIndex("by_room_request", q => q.eq("roomId", room._id).eq("requestId", requestId)).unique();
    if (previous) {
      if (previous.requestPayload !== requestPayload) fail(409, "requestId already used with different payload");
      return roomState(ctx, room);
    }
    validSchedule(payload.scheduledAt);
    if (room.activeTripId) fail(409, "Room already has an active trip");
    if (room.tripCount >= limits.trips) fail(409, "Room trip limit reached");
    const now = new Date().toISOString();
    const tripId = await ctx.db.insert("trips", {
      roomId: room._id, requestId, requestPayload,
      payload: { id: randomId(), riderId: participant.id, riderName: participant.name, ...payload,
        status: "requested", driver: null, fareCents: fares[payload.service] + 300 * payload.stops.length,
        createdAt: now, updatedAt: now, cancellationReason: null, rating: null, tipCents: 0, messages: [] },
    });
    await ctx.db.patch(room._id, { activeTripId: tripId, tripCount: room.tripCount + 1 });
    return changed(ctx, room);
  },
});

type Action = { action: string; reason?: string | null; rating?: number | null; tipCents?: number | null; text?: string | null };

export const act = mutation({
  args: v.any(),
  handler: async (ctx, args: { token: string; tripID: string; action: Action }) => {
    const input = object(args, "arguments");
    const { participant, room } = await authenticate(ctx, input.token);
    const tripID = text(input.tripID, 100, "tripID");
    const actionInput = object(input.action, "action");
    const action = text(actionInput.action, 20, "action");
    const row = await ctx.db.query("trips").withIndex("by_room_id", q => q.eq("roomId", room._id).eq("payload.id", tripID)).unique();
    if (!row) fail(404, "Trip not found");
    const trip = row.payload;
    const owner = participant.role === "rider" && participant.id === trip.riderId;
    const assigned = participant.role === "driver" && participant.id === trip.driver?.id;
    if (action === "accept") {
      if (participant.role !== "driver") fail(403, "Driver role required");
      if (!participant.online) fail(409, "Driver must be online");
      if (trip.status !== "requested" || room.activeTripId !== row._id) fail(409, "Trip is no longer available");
      trip.status = "accepted";
      trip.driver = { id: participant.id, name: participant.name, vehicle: "Toyota Prius", plate: "DEMO 24", rating: 4.98 };
    } else if (action === "arrive" || action === "start" || action === "complete") {
      if (!assigned) fail(403, "Assigned driver required");
      const transition = { arrive: ["accepted", "arriving"], start: ["arriving", "in_progress"], complete: ["in_progress", "completed"] } as const;
      if (trip.status !== transition[action][0]) fail(409, `Cannot ${action} trip from ${trip.status}`);
      trip.status = transition[action][1];
    } else if (action === "cancel") {
      if (!owner && !assigned) fail(403, "Trip owner or assigned driver required");
      if (!["requested", "accepted", "arriving"].includes(trip.status)) fail(409, `Cannot cancel trip from ${trip.status}`);
      trip.status = "cancelled";
      trip.cancellationReason = actionInput.reason === undefined || actionInput.reason === null ? null : text(actionInput.reason, 300, "reason", false);
    } else if (action === "rate") {
      if (!owner) fail(403, "Trip owner rider required");
      if (trip.status !== "completed") fail(409, "Only completed trips can be rated");
      const { rating, tipCents } = actionInput;
      if (typeof rating !== "number" || !Number.isInteger(rating) || rating < 1 || rating > 5) fail(400, "rating must be an integer from 1 to 5");
      if (typeof tipCents !== "number" || !Number.isInteger(tipCents) || tipCents < 0 || tipCents > 10_000) fail(400, "tipCents must be an integer from 0 to 10000");
      trip.rating = rating;
      trip.tipCents = tipCents;
    } else if (action === "message") {
      if (!owner && !assigned) fail(403, "Trip owner or assigned driver required");
      if (!["accepted", "arriving", "in_progress"].includes(trip.status)) fail(409, "Chat is unavailable for this trip");
      if (trip.messages.length >= limits.messages) fail(409, "Message history is full");
      const messageText = text(actionInput.text, 500, "text");
      trip.messages.push({ id: randomId(), senderId: participant.id, senderName: participant.name, text: messageText, createdAt: new Date().toISOString() });
    } else fail(400, "Unsupported action");
    trip.updatedAt = new Date().toISOString();
    await ctx.db.patch(row._id, { payload: trip });
    if (trip.status === "completed" || trip.status === "cancelled") {
      if (room.activeTripId === row._id) await ctx.db.patch(room._id, { activeTripId: null });
    }
    return changed(ctx, room);
  },
});
