import { v } from "convex/values";
import { action, mutation, query } from "./_generated/server";
import { internal } from "./_generated/api";
import { authenticate, authenticateSession, publicAccount } from "./accountAuth";
import { accountState, advanceArea } from "./dispatchState";
import type { AccountSession, SignIn, SignUp } from "./accountTypes";
import { fail, object, tokenHash } from "./validation";

export const signUp = action({
  args: v.any(),
  handler: async (ctx, args: SignUp): Promise<AccountSession> => ctx.runAction(internal.accountActions.signUp, args),
});

export const signIn = action({
  args: v.any(),
  handler: async (ctx, args: SignIn): Promise<AccountSession> => ctx.runAction(internal.accountActions.signIn, args),
});

export const profile = query({
  args: v.any(),
  handler: async (ctx, args: { token: string }) => publicAccount(await authenticate(ctx, object(args, "arguments").token)),
});

export const resume = query({
  args: v.any(),
  handler: async (ctx, args: { token: string }): Promise<AccountSession> => {
    const input = object(args, "arguments");
    const { user, session } = await authenticateSession(ctx, input.token);
    return { roomCode: user._id, participantId: user._id, token: input.token as string, role: user.role,
      name: user.name, account: publicAccount(user), expiresAt: session.expiresAt, state: await accountState(ctx, user) };
  },
});

export const signOut = mutation({
  args: v.any(),
  handler: async (ctx, args: { token: string }) => {
    const hash = await tokenHash(object(args, "arguments").token);
    const session = await ctx.db.query("sessions").withIndex("by_hash", q => q.eq("tokenHash", hash)).unique();
    if (!session) return true;
    if (Date.now() >= session.expiresAt) {
      await ctx.db.delete(session._id);
      return true;
    }
    const user = await ctx.db.get(session.userId);
    if (user?.activeTripId) fail(409, "Cannot sign out during an active trip");
    if (user?.role === "driver" && user.online) {
      await ctx.db.patch(user._id, { online: false });
      await advanceArea(ctx, user.serviceArea);
    }
    await ctx.db.delete(session._id);
    return true;
  },
});
