import { v } from "convex/values";
import { mutation, query, type MutationCtx } from "./_generated/server";
import type { Doc } from "./_generated/dataModel";
import { authenticate } from "./accountAuth";
import { accountState, advanceArea } from "./dispatchState";
import { booking, fail, fares, limits, object, randomId, text, validSchedule } from "./validation";

async function changed(ctx: MutationCtx, user: Doc<"users">) {
  await advanceArea(ctx, user.serviceArea);
  return accountState(ctx, (await ctx.db.get(user._id))!);
}

export const state = query({
  args: v.any(),
  handler: async (ctx, args: { token: string }) => {
    const user = await authenticate(ctx, object(args, "arguments").token);
    return accountState(ctx, user);
  },
});

export const availability = mutation({
  args: v.any(),
  handler: async (ctx, args: { token: string; online: boolean }) => {
    const input = object(args, "arguments");
    const user = await authenticate(ctx, input.token);
    if (user.role !== "driver") fail(403, "Driver role required");
    if (typeof input.online !== "boolean") fail(400, "online must be boolean");
    if (!input.online && user.activeTripId) fail(409, "Cannot go offline during an active trip");
    await ctx.db.patch(user._id, { online: input.online });
    return changed(ctx, user);
  },
});

type Place = { id: string; name: string; address: string; latitude: number; longitude: number };
type Request = { requestId: string; pickup: Place; destination: Place; stops: Place[]; service: string;
  paymentMethod: string; scheduledAt?: string | null; note: string };

export const book = mutation({
  args: v.any(),
  handler: async (ctx, args: { token: string; request: Request }) => {
    const input = object(args, "arguments");
    const user = await authenticate(ctx, input.token);
    if (user.role !== "rider") fail(403, "Rider role required");
    const { requestId, payload } = booking(input.request);
    const requestPayload = JSON.stringify(payload);
    const previous = await ctx.db.query("dispatchTrips").withIndex("by_rider_request", q =>
      q.eq("riderId", user._id).eq("requestId", requestId)).unique();
    if (previous) {
      if (previous.requestPayload !== requestPayload) fail(409, "requestId already used with different payload");
      return accountState(ctx, user);
    }
    validSchedule(payload.scheduledAt);
    if (user.activeTripId) fail(409, "Rider already has an active trip");
    const now = new Date().toISOString();
    const tripId = await ctx.db.insert("dispatchTrips", {
      riderId: user._id, driverId: null, serviceArea: user.serviceArea, status: "requested", requestId, requestPayload,
      payload: { id: randomId(), riderId: user._id, riderName: user.name, ...payload,
        status: "requested", driver: null, fareCents: fares[payload.service] + 300 * payload.stops.length,
        createdAt: now, updatedAt: now, cancellationReason: null, rating: null, tipCents: 0, messages: [] },
    });
    await ctx.db.patch(user._id, { activeTripId: tripId });
    return changed(ctx, user);
  },
});

type Action = { action: string; reason?: string | null; rating?: number | null; tipCents?: number | null; text?: string | null };

export const act = mutation({
  args: v.any(),
  handler: async (ctx, args: { token: string; tripID: string; action: Action }) => {
    const input = object(args, "arguments");
    const user = await authenticate(ctx, input.token);
    const tripID = text(input.tripID, 100, "tripID");
    const actionInput = object(input.action, "action");
    const action = text(actionInput.action, 20, "action");
    const row = await ctx.db.query("dispatchTrips").withIndex("by_trip_id", q => q.eq("payload.id", tripID)).unique();
    if (!row || row.serviceArea !== user.serviceArea || (user.role === "rider" && row.riderId !== user._id)) fail(404, "Trip not found");
    const trip = row.payload;
    const owner = user.role === "rider" && row.riderId === user._id;
    const assigned = user.role === "driver" && row.driverId === user._id;
    if (action === "accept") {
      if (user.role !== "driver") fail(403, "Driver role required");
      if (!user.online) fail(409, "Driver must be online");
      const rider = (await ctx.db.get(row.riderId))!;
      if (trip.status !== "requested" || rider.activeTripId !== row._id) fail(409, "Trip is no longer available");
      if (user.activeTripId) fail(409, "Driver already has an active trip");
      trip.status = "accepted";
      trip.driver = { id: user._id, name: user.name, vehicle: user.vehicle!, plate: user.plate!, rating: 0 };
      row.driverId = user._id;
      await ctx.db.patch(user._id, { activeTripId: row._id });
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
      trip.messages.push({ id: randomId(), senderId: user._id, senderName: user.name, text: messageText, createdAt: new Date().toISOString() });
    } else fail(400, "Unsupported action");
    trip.updatedAt = new Date().toISOString();
    await ctx.db.patch(row._id, { payload: trip, status: trip.status, driverId: row.driverId });
    if (trip.status === "completed" || trip.status === "cancelled") {
      for (const id of [row.riderId, ...(row.driverId ? [row.driverId] : [])]) {
        const participant = (await ctx.db.get(id))!;
        if (participant.activeTripId === row._id) await ctx.db.patch(id, { activeTripId: null });
      }
    }
    return changed(ctx, user);
  },
});
