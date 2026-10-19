import { v } from "convex/values";
import { internalMutation, type MutationCtx } from "./_generated/server";
import type { Doc } from "./_generated/dataModel";
import { role } from "./schema";
import { loginLimit, loginWindow, publicAccount, sessionLifetime } from "./accountAuth";
import type { AccountSession } from "./accountTypes";
import { accountState } from "./dispatchState";
import { fail } from "./validation";

async function createSession(ctx: MutationCtx, user: Doc<"users">, hash: string): Promise<Omit<AccountSession, "token">> {
  const expiresAt = Date.now() + sessionLifetime;
  await ctx.db.insert("sessions", { userId: user._id, tokenHash: hash, expiresAt });
  return { roomCode: user._id, participantId: user._id, name: user.name, role: user.role,
    state: await accountState(ctx, user), account: publicAccount(user), expiresAt };
}

export const register = internalMutation({
  args: {
    name: v.string(), email: v.string(), role, passwordSalt: v.string(), passwordHash: v.string(),
    vehicle: v.union(v.string(), v.null()), plate: v.union(v.string(), v.null()), serviceArea: v.string(),
    sessionHash: v.string(),
  },
  handler: async (ctx, args): Promise<Omit<AccountSession, "token">> => {
    if (await ctx.db.query("users").withIndex("by_email", q => q.eq("email", args.email)).unique()) {
      fail(409, "Unable to create account");
    }
    const { sessionHash, ...profile } = args;
    const id = await ctx.db.insert("users", { ...profile, online: false, activeTripId: null,
      loginWindowStart: 0, loginAttempts: 0 });
    return createSession(ctx, (await ctx.db.get(id))!, sessionHash);
  },
});

export const beginLogin = internalMutation({
  args: { email: v.string() },
  handler: async (ctx, { email }) => {
    const user = await ctx.db.query("users").withIndex("by_email", q => q.eq("email", email)).unique();
    if (!user) return null;
    const now = Date.now();
    const reset = now >= user.loginWindowStart + loginWindow;
    const attempts = reset ? 0 : user.loginAttempts;
    if (attempts >= loginLimit) return null;
    await ctx.db.patch(user._id, { loginWindowStart: reset ? now : user.loginWindowStart, loginAttempts: attempts + 1 });
    return { id: user._id, passwordSalt: user.passwordSalt, passwordHash: user.passwordHash };
  },
});

export const finishLogin = internalMutation({
  args: { userId: v.id("users"), passwordHash: v.string(), sessionHash: v.string() },
  handler: async (ctx, args): Promise<Omit<AccountSession, "token">> => {
    const user = await ctx.db.get(args.userId);
    if (!user || user.passwordHash !== args.passwordHash) fail(401, "Invalid email or password");
    return createSession(ctx, user, args.sessionHash);
  },
});
