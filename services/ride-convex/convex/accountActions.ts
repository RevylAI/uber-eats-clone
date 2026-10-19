"use node";

import { createHash, randomBytes, scrypt, timingSafeEqual } from "node:crypto";
import { v } from "convex/values";
import { internalAction } from "./_generated/server";
import { internal } from "./_generated/api";
import type { AccountSession, SignIn, SignUp } from "./accountTypes";
import { fail, object, text } from "./validation";

function emailAddress(value: unknown): string {
  const email = text(value, 254, "email").toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) fail(400, "Invalid email");
  return email;
}

function passwordValue(value: unknown): string {
  if (typeof value !== "string" || value.length < 12 || value.length > 128) fail(400, "Password must contain 12 to 128 characters");
  return value;
}

async function passwordDigest(password: string, salt: string): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    scrypt(password, salt, 64, { N: 32768, r: 8, p: 3, maxmem: 64 * 1024 * 1024 }, (error, key) => {
      if (error) reject(new Error("Password processing unavailable"));
      else resolve(key);
    });
  });
}

function credential() {
  const token = `user.${randomBytes(32).toString("base64url")}`;
  return { token, sessionHash: createHash("sha256").update(token).digest("hex") };
}

export const signUp = internalAction({
  args: v.any(),
  handler: async (ctx, args: SignUp): Promise<AccountSession> => {
    const input = object(args, "arguments");
    const name = text(input.name, 80, "name");
    const email = emailAddress(input.email);
    const password = passwordValue(input.password);
    const role = input.role;
    if (role !== "rider" && role !== "driver") fail(400, "Invalid role");
    const vehicle = input.vehicle === undefined ? null : text(input.vehicle, 100, "vehicle");
    const plate = input.plate === undefined ? null : text(input.plate, 20, "plate");
    if (role === "driver" && (!vehicle || !plate)) fail(400, "Driver vehicle and plate are required");
    const serviceArea = input.serviceArea === undefined ? "austin" : text(input.serviceArea, 80, "serviceArea").toLowerCase();
    if (!/^[a-z0-9][a-z0-9-]{0,79}$/.test(serviceArea)) fail(400, "Invalid serviceArea");
    const passwordSalt = randomBytes(16).toString("hex");
    const passwordHash = (await passwordDigest(password, passwordSalt)).toString("hex");
    const { token, sessionHash } = credential();
    const session = await ctx.runMutation(internal.accountStore.register, {
      name, email, role, vehicle: role === "driver" ? vehicle : null, plate: role === "driver" ? plate : null,
      serviceArea, passwordSalt, passwordHash, sessionHash,
    });
    return { ...session, token };
  },
});

export const signIn = internalAction({
  args: v.any(),
  handler: async (ctx, args: SignIn): Promise<AccountSession> => {
    const input = object(args, "arguments");
    if (typeof input.email !== "string" || input.email.length > 254 ||
      typeof input.password !== "string" || input.password.length > 128) fail(401, "Invalid email or password");
    const email = input.email.trim().toLowerCase();
    const candidate = await ctx.runMutation(internal.accountStore.beginLogin, { email });
    const digest = await passwordDigest(input.password, candidate?.passwordSalt ?? "00000000000000000000000000000000");
    const expected = Buffer.from(candidate?.passwordHash ?? "00".repeat(64), "hex");
    if (!timingSafeEqual(digest, expected) || !candidate) fail(401, "Invalid email or password");
    const { token, sessionHash } = credential();
    const session = await ctx.runMutation(internal.accountStore.finishLogin, {
      userId: candidate.id, passwordHash: candidate.passwordHash, sessionHash,
    });
    return { ...session, token };
  },
});
