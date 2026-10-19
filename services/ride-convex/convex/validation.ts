import { ConvexError, type Infer } from "convex/values";
import { place } from "./schema";

export const fares: Record<string, number> = {
  uberX: 1840, comfort: 2490, uberXL: 2990, green: 1940, black: 3890, pet: 2140,
};
export const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
export const ttl = 24 * 60 * 60_000;
export const limits = { participants: 32, credentials: 128, trips: 20, messages: 100 };

export function fail(status: number, message: string): never {
  throw new ConvexError({ status, message });
}

export function object(value: unknown, field: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) fail(400, `Invalid ${field}`);
  return value as Record<string, unknown>;
}

export function text(value: unknown, max: number, field: string, required = true): string {
  if (typeof value !== "string" || (required && !value.trim()) || value.length > max) fail(400, `Invalid ${field}`);
  return value.trim();
}

export async function tokenHash(value: unknown): Promise<string> {
  if (typeof value !== "string" || value.length < 32 || value.length > 256) {
    fail(401, "Invalid bearer token");
  }
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(bytes), byte => byte.toString(16).padStart(2, "0")).join("");
}

export async function invitation(token: string, attempt: number): Promise<string> {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`ride-room-invitation-v1:${attempt}:${token}`));
  return Array.from(new Uint8Array(bytes).slice(0, 16), byte => alphabet[byte & 31]).join("");
}

export function randomString(length: number, characters: string): string {
  return Array.from({ length }, () => characters[Math.floor(Math.random() * characters.length)]).join("");
}

export const randomId = () => randomString(32, "0123456789abcdef");

function coordinate(value: unknown, min: number, max: number, field: string): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < min || value > max) fail(400, `Invalid ${field}`);
  return value;
}

function validPlace(value: unknown, field: string): Infer<typeof place> {
  const input = object(value, field);
  return {
    id: text(input.id, 100, `${field}.id`), name: text(input.name, 200, `${field}.name`),
    address: text(input.address, 300, `${field}.address`),
    latitude: coordinate(input.latitude, -90, 90, `${field}.latitude`),
    longitude: coordinate(input.longitude, -180, 180, `${field}.longitude`),
  };
}

export function booking(value: unknown) {
  const input = object(value, "request");
  const requestId = text(input.requestId, 36, "requestId");
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(requestId)) {
    fail(400, "requestId must be a UUID");
  }
  const pickup = validPlace(input.pickup, "pickup");
  const destination = validPlace(input.destination, "destination");
  if (!Array.isArray(input.stops) || input.stops.length > 2) fail(400, "stops must contain at most 2 places");
  const stops = input.stops.map((value, index) => validPlace(value, `stops[${index}]`));
  const points = [pickup, ...stops, destination];
  if (new Set(points.map(point => point.id)).size !== points.length) fail(400, "Route place IDs must be unique");
  if (new Set(points.map(point => `${point.latitude},${point.longitude}`)).size !== points.length) fail(400, "Route coordinates must be unique");
  if (typeof input.service !== "string" || !Object.hasOwn(fares, input.service)) fail(400, "Unsupported service");
  const paymentMethod = text(input.paymentMethod, 80, "paymentMethod");
  if (/[0-9]{12,}/.test(paymentMethod)) fail(400, "Payment details are not accepted");
  let scheduledAt: string | null = null;
  if (input.scheduledAt !== undefined && input.scheduledAt !== null) {
    if (typeof input.scheduledAt !== "string" || input.scheduledAt.length > 40 ||
      !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,3})?(?:Z|[+-]\d\d:\d\d)$/.test(input.scheduledAt) ||
      !Number.isFinite(Date.parse(input.scheduledAt))) fail(400, "Invalid scheduledAt");
    const calendar = input.scheduledAt.slice(0, 10);
    const calendarDate = Date.parse(`${calendar}T00:00:00Z`);
    if (!Number.isFinite(calendarDate) || new Date(calendarDate).toISOString().slice(0, 10) !== calendar ||
      Number(input.scheduledAt.slice(11, 13)) > 23 || Number(input.scheduledAt.slice(14, 16)) > 59 ||
      Number(input.scheduledAt.slice(17, 19)) > 59) fail(400, "Invalid scheduledAt");
    scheduledAt = new Date(input.scheduledAt).toISOString();
  }
  const note = input.note === undefined ? "" : text(input.note, 500, "note", false);
  return { requestId, payload: { pickup, destination, stops, service: input.service, paymentMethod, scheduledAt, note } };
}

export function validSchedule(scheduledAt: string | null) {
  if (scheduledAt === null) return;
  const delta = Date.parse(scheduledAt) - Date.now();
  if (delta <= 0 || delta > 30 * ttl) fail(400, "scheduledAt must be within the next 30 days");
}
