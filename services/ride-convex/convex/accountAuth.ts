import type { Doc } from "./_generated/dataModel";
import type { MutationCtx, QueryCtx } from "./_generated/server";
import type { Account } from "./accountTypes";
import { fail, tokenHash } from "./validation";

export const sessionLifetime = 30 * 24 * 60 * 60_000;
export const loginWindow = 15 * 60_000;
export const loginLimit = 5;

export function publicAccount(user: Doc<"users">): Account {
  return { id: user._id, name: user.name, email: user.email, role: user.role,
    vehicle: user.vehicle, plate: user.plate };
}

export async function authenticateSession(ctx: QueryCtx | MutationCtx, token: unknown) {
  const hash = await tokenHash(token);
  const session = await ctx.db.query("sessions").withIndex("by_hash", q => q.eq("tokenHash", hash)).unique();
  if (!session || Date.now() >= session.expiresAt) fail(401, "Invalid or expired bearer token");
  const user = await ctx.db.get(session.userId);
  if (!user) fail(401, "Invalid or expired bearer token");
  return { user, session };
}

export async function authenticate(ctx: QueryCtx | MutationCtx, token: unknown): Promise<Doc<"users">> {
  return (await authenticateSession(ctx, token)).user;
}
