import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export const role = v.union(v.literal("rider"), v.literal("driver"));
export const place = v.object({
  id: v.string(), name: v.string(), address: v.string(),
  latitude: v.number(), longitude: v.number(),
});
export const message = v.object({
  id: v.string(), senderId: v.string(), senderName: v.string(),
  text: v.string(), createdAt: v.string(),
});
export const trip = v.object({
  id: v.string(), riderId: v.string(), riderName: v.string(),
  pickup: place, destination: place, stops: v.array(place),
  service: v.string(), paymentMethod: v.string(), scheduledAt: v.union(v.string(), v.null()),
  note: v.string(),
  status: v.union(v.literal("requested"), v.literal("accepted"), v.literal("arriving"),
    v.literal("in_progress"), v.literal("completed"), v.literal("cancelled")),
  driver: v.union(v.object({
    id: v.string(), name: v.string(), vehicle: v.string(), plate: v.string(), rating: v.number(),
  }), v.null()),
  fareCents: v.number(), createdAt: v.string(), updatedAt: v.string(),
  cancellationReason: v.union(v.string(), v.null()), rating: v.union(v.number(), v.null()),
  tipCents: v.number(), messages: v.array(message),
});

export default defineSchema({
  users: defineTable({
    name: v.string(), email: v.string(), role, passwordSalt: v.string(), passwordHash: v.string(),
    vehicle: v.union(v.string(), v.null()), plate: v.union(v.string(), v.null()),
    serviceArea: v.string(), online: v.boolean(),
    activeTripId: v.union(v.id("dispatchTrips"), v.null()),
    loginWindowStart: v.number(), loginAttempts: v.number(),
  }).index("by_email", ["email"]).index("by_area_role_online", ["serviceArea", "role", "online"]),
  sessions: defineTable({
    userId: v.id("users"), tokenHash: v.string(), expiresAt: v.number(),
  }).index("by_hash", ["tokenHash"]),
  dispatchAreas: defineTable({ name: v.string(), revision: v.number() }).index("by_name", ["name"]),
  dispatchTrips: defineTable({
    riderId: v.id("users"), driverId: v.union(v.id("users"), v.null()), serviceArea: v.string(),
    status: v.string(), requestId: v.string(), requestPayload: v.string(), payload: trip,
  }).index("by_rider", ["riderId"]).index("by_driver", ["driverId"])
    .index("by_area_status", ["serviceArea", "status"])
    .index("by_rider_request", ["riderId", "requestId"]).index("by_trip_id", ["payload.id"]),
  rooms: defineTable({
    code: v.string(), riderId: v.string(), revision: v.number(), expiresAt: v.number(),
    activeTripId: v.union(v.id("trips"), v.null()),
    tripCount: v.number(), participantCount: v.number(), credentialCount: v.number(),
  }).index("by_code", ["code"]),
  participants: defineTable({
    roomId: v.id("rooms"), id: v.string(), role, name: v.string(), online: v.boolean(),
  }).index("by_room", ["roomId"]).index("by_room_id", ["roomId", "id"]),
  credentials: defineTable({
    tokenHash: v.string(), participantId: v.id("participants"), expiresAt: v.number(),
  }).index("by_hash", ["tokenHash"]),
  trips: defineTable({
    roomId: v.id("rooms"), requestId: v.string(), requestPayload: v.string(), payload: trip,
  }).index("by_room", ["roomId"]).index("by_room_request", ["roomId", "requestId"])
    .index("by_room_id", ["roomId", "payload.id"]),
});
