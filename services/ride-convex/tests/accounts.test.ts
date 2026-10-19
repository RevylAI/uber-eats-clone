// @vitest-environment node
import { createHash, scryptSync } from "node:crypto";
import { convexTest } from "convex-test";
import { afterEach, describe, expect, test, vi } from "vitest";
import { api } from "../convex/_generated/api";
import schema from "../convex/schema";
import { loginLimit, loginWindow, sessionLifetime } from "../convex/accountAuth";

const modules = import.meta.glob("../convex/**/*.ts");
const password = "correct horse battery staple";
const registration = (overrides = {}) => ({
  name: "Alex", email: `${crypto.randomUUID()}@example.test`, password, role: "rider", ...overrides,
});
const backend = () => convexTest({ schema, modules, transactionLimits: true });
const request = () => ({
  requestId: crypto.randomUUID(),
  pickup: { id: "pickup", name: "Pickup", address: "1 Main Street", latitude: 30.2, longitude: -97.7 },
  destination: { id: "destination", name: "Destination", address: "2 Main Street", latitude: 30.3, longitude: -97.8 },
  stops: [], service: "uberX", paymentMethod: "Visa •••• 4242", note: "",
});
const failure = (promise: Promise<unknown>, status: number, message?: string) =>
  expect(promise).rejects.toMatchObject({ data: { status, ...(message ? { message } : {}) } });

afterEach(() => vi.useRealTimers());

describe("database-backed accounts", () => {
  test("registration and resume return matching account identity, not invitations", async () => {
    const t = backend();
    const args = registration({ email: "  Alex@Example.Test ", name: " Alex " });
    const session = await t.action(api.accounts.signUp, args);
    expect(session.account).toEqual({ id: session.participantId, name: "Alex", email: "alex@example.test",
      role: "rider", vehicle: null, plate: null });
    expect(session.roomCode).toBe(session.account.id);
    expect(session.state).toEqual({ roomCode: session.account.id, revision: 0, driverOnline: false, onlineDriverIds: [], trips: [] });
    expect(session.role).toBe(session.account.role);
    expect(session.name).toBe(session.account.name);
    expect(session.token).toMatch(/^user\.[A-Za-z0-9_-]{43}$/);
    expect(Buffer.from(session.token.slice(5), "base64url")).toHaveLength(32);
    expect(session.expiresAt - Date.now()).toBeGreaterThan(sessionLifetime - 5000);
    expect(session.expiresAt - Date.now()).toBeLessThanOrEqual(sessionLifetime);
    expect(await t.query(api.accounts.resume, { token: session.token })).toEqual(session);
    expect(await t.query(api.accounts.profile, { token: session.token })).toEqual(session.account);
    expect(await t.run(ctx => ctx.db.query("rooms").collect())).toEqual([]);
    expect(await t.run(ctx => ctx.db.query("participants").collect())).toEqual([]);
    await failure(t.query(api.rides.state, { token: session.token }), 401);
  });

  test("driver profiles persist supplied vehicle and plate and default to Austin offline", async () => {
    const t = backend();
    const args = registration({ role: "driver", vehicle: "Honda Civic", plate: "TX 1234" });
    const session = await t.action(api.accounts.signUp, args);
    expect(session.account).toMatchObject({ role: "driver", vehicle: "Honda Civic", plate: "TX 1234" });
    const user = await t.run(ctx => ctx.db.query("users").first());
    expect(user).toMatchObject({ serviceArea: "austin", online: false });
    const signedIn = await t.action(api.accounts.signIn, { email: args.email, password });
    expect(signedIn.account).toEqual(session.account);
    expect(signedIn.token).not.toBe(session.token);
  });

  test("passwords use independent salted scrypt hashes and sessions store only SHA-256 digests", async () => {
    const t = backend();
    const first = await t.action(api.accounts.signUp, registration());
    const second = await t.action(api.accounts.signUp, registration());
    const tables = await t.run(async ctx => ({ users: await ctx.db.query("users").collect(), sessions: await ctx.db.query("sessions").collect() }));
    expect(tables.users[0].passwordSalt).not.toBe(tables.users[1].passwordSalt);
    expect(tables.users[0].passwordHash).not.toBe(tables.users[1].passwordHash);
    for (const user of tables.users) {
      expect(user.passwordSalt).toMatch(/^[0-9a-f]{32}$/);
      expect(user.passwordHash).toMatch(/^[0-9a-f]{128}$/);
      expect(scryptSync(password, user.passwordSalt, 64, { N: 32768, r: 8, p: 3, maxmem: 64 * 1024 * 1024 }).toString("hex")).toBe(user.passwordHash);
      expect(user.passwordHash).not.toBe(createHash("sha256").update(password).digest("hex"));
    }
    for (const session of [first, second]) {
      expect(tables.sessions.find(row => row.userId === session.account.id)?.tokenHash)
        .toBe(createHash("sha256").update(session.token).digest("hex"));
      expect(JSON.stringify(tables)).not.toContain(session.token);
    }
    expect(JSON.stringify(tables)).not.toContain(password);
  });

  test("sign-in normalizes email but preserves password whitespace and generates fresh sessions", async () => {
    const t = backend();
    const args = registration({ password: ` ${password} ` });
    const signedUp = await t.action(api.accounts.signUp, args);
    const signedIn = await t.action(api.accounts.signIn, { email: ` ${args.email.toUpperCase()} `, password: args.password });
    expect(signedIn.account).toEqual(signedUp.account);
    expect(signedIn.token).not.toBe(signedUp.token);
    await failure(t.action(api.accounts.signIn, { email: args.email, password }), 401, "Invalid email or password");
    expect(await t.query(api.accounts.resume, { token: signedUp.token })).toEqual(signedUp);
  });

  test("duplicate and simultaneous normalized registration cannot replace existing users", async () => {
    const t = backend();
    const args = registration();
    const results = await Promise.allSettled([
      t.action(api.accounts.signUp, args),
      t.action(api.accounts.signUp, { ...args, email: args.email.toUpperCase(), name: "Imposter", role: "driver", vehicle: "Other", plate: "ABC" }),
    ]);
    expect(results.filter(result => result.status === "fulfilled")).toHaveLength(1);
    expect(results.find(result => result.status === "rejected")).toMatchObject({ reason: { data: { status: 409 } } });
    expect(await t.run(ctx => ctx.db.query("users").collect())).toHaveLength(1);
    expect(await t.run(ctx => ctx.db.query("sessions").collect())).toHaveLength(1);
  });

  test("sign-out revokes only the presented session and is idempotent", async () => {
    const t = backend();
    const args = registration();
    const original = await t.action(api.accounts.signUp, args);
    const next = await t.action(api.accounts.signIn, { email: args.email, password });
    expect(await t.mutation(api.accounts.signOut, { token: original.token })).toBe(true);
    expect(await t.mutation(api.accounts.signOut, { token: original.token })).toBe(true);
    await failure(t.query(api.accounts.resume, { token: original.token }), 401);
    await failure(t.query(api.accounts.profile, { token: original.token }), 401);
    await failure(t.query(api.dispatch.state, { token: original.token }), 401);
    expect((await t.query(api.accounts.resume, { token: next.token })).account).toEqual(original.account);
    expect(await t.run(ctx => ctx.db.query("users").collect())).toHaveLength(1);
  });

  test("expiry applies at the exact boundary to account reads and all dispatch operations", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    const t = backend();
    const args = registration();
    const session = await t.action(api.accounts.signUp, args);
    vi.setSystemTime(session.expiresAt - 1);
    expect((await t.query(api.accounts.resume, { token: session.token })).expiresAt).toBe(session.expiresAt);
    vi.setSystemTime(session.expiresAt);
    const calls = [
      t.query(api.accounts.resume, { token: session.token }), t.query(api.accounts.profile, { token: session.token }),
      t.query(api.dispatch.state, { token: session.token }),
      t.mutation(api.dispatch.availability, { token: session.token, online: true }),
      t.mutation(api.dispatch.book, { token: session.token, request: null } as never),
      t.mutation(api.dispatch.act, { token: session.token, tripID: "missing", action: { action: "cancel" } }),
    ];
    for (const result of await Promise.allSettled(calls)) {
      expect(result).toMatchObject({ status: "rejected", reason: { data: { status: 401 } } });
    }
    const fresh = await t.action(api.accounts.signIn, { email: args.email, password });
    expect(fresh.account).toEqual(session.account);
    expect(fresh.expiresAt).toBe(Date.now() + sessionLifetime);
    expect(await t.mutation(api.accounts.signOut, { token: session.token })).toBe(true);
  });

  test("sign-out guards active rider and driver trips, then takes the driver offline atomically", async () => {
    const t = backend();
    const serviceArea = `test-${crypto.randomUUID()}`;
    const rider = await t.action(api.accounts.signUp, registration({ serviceArea }));
    const driver = await t.action(api.accounts.signUp, registration({ serviceArea, role: "driver", vehicle: "Car", plate: "TX 123" }));
    await t.mutation(api.dispatch.availability, { token: driver.token, online: true });
    const tripID = (await t.mutation(api.dispatch.book, { token: rider.token, request: request() })).trips[0].id;
    await failure(t.mutation(api.accounts.signOut, { token: rider.token }), 409, "Cannot sign out during an active trip");
    await t.mutation(api.dispatch.act, { token: driver.token, tripID, action: { action: "accept" } });
    await failure(t.mutation(api.accounts.signOut, { token: driver.token }), 409, "Cannot sign out during an active trip");
    expect((await t.query(api.accounts.resume, { token: driver.token })).state.onlineDriverIds).toContain(driver.participantId);
    await t.mutation(api.dispatch.act, { token: rider.token, tripID, action: { action: "cancel" } });
    const before = await t.query(api.dispatch.state, { token: rider.token });
    expect(await t.mutation(api.accounts.signOut, { token: driver.token })).toBe(true);
    const after = await t.query(api.dispatch.state, { token: rider.token });
    expect(after.revision).toBe(before.revision + 1);
    expect(after.driverOnline).toBe(false);
    expect(after.onlineDriverIds).not.toContain(driver.participantId);
    await failure(t.query(api.accounts.resume, { token: driver.token }), 401);
    expect(await t.mutation(api.accounts.signOut, { token: driver.token })).toBe(true);
    expect(await t.query(api.dispatch.state, { token: rider.token })).toEqual(after);
  });

  test("sign-out racing acceptance cannot leave a revoked online driver assigned to a trip", async () => {
    const t = backend();
    const serviceArea = `test-${crypto.randomUUID()}`;
    const rider = await t.action(api.accounts.signUp, registration({ serviceArea }));
    const driver = await t.action(api.accounts.signUp, registration({ serviceArea, role: "driver", vehicle: "Car", plate: "TX 123" }));
    await t.mutation(api.dispatch.availability, { token: driver.token, online: true });
    const tripID = (await t.mutation(api.dispatch.book, { token: rider.token, request: request() })).trips[0].id;
    const results = await Promise.allSettled([
      t.mutation(api.accounts.signOut, { token: driver.token }),
      t.mutation(api.dispatch.act, { token: driver.token, tripID, action: { action: "accept" } }),
    ]);
    expect(results.filter(result => result.status === "fulfilled")).toHaveLength(1);
    const state = await t.query(api.dispatch.state, { token: rider.token });
    if (results[0].status === "fulfilled") {
      expect(state.driverOnline).toBe(false);
      expect(state.trips[0]).toMatchObject({ status: "requested", driver: null });
      await failure(t.query(api.accounts.resume, { token: driver.token }), 401);
    } else {
      expect(results[0]).toMatchObject({ reason: { data: { status: 409 } } });
      expect(state.trips[0].driver?.id).toBe(driver.participantId);
      expect((await t.query(api.accounts.resume, { token: driver.token })).state.onlineDriverIds).toContain(driver.participantId);
    }
  });

  test("an expired session cannot sign out the driver's live session or change availability", async () => {
    const t = backend();
    const serviceArea = `test-${crypto.randomUUID()}`;
    const rider = await t.action(api.accounts.signUp, registration({ serviceArea }));
    const args = registration({ serviceArea, role: "driver", vehicle: "Car", plate: "TX 123" });
    const old = await t.action(api.accounts.signUp, args);
    const driver = await t.action(api.accounts.signIn, { email: args.email, password });
    await t.mutation(api.dispatch.availability, { token: driver.token, online: true });
    const tripID = (await t.mutation(api.dispatch.book, { token: rider.token, request: request() })).trips[0].id;
    await t.mutation(api.dispatch.act, { token: driver.token, tripID, action: { action: "accept" } });
    await t.run(async ctx => {
      const oldHash = createHash("sha256").update(old.token).digest("hex");
      const session = (await ctx.db.query("sessions").withIndex("by_hash", q => q.eq("tokenHash", oldHash)).unique())!;
      await ctx.db.patch(session._id, { expiresAt: Date.now() });
    });
    const before = await t.query(api.accounts.resume, { token: driver.token });
    expect(await t.mutation(api.accounts.signOut, { token: old.token })).toBe(true);
    expect(await t.query(api.accounts.resume, { token: driver.token })).toEqual(before);
    expect(before.state.onlineDriverIds).toContain(driver.participantId);
    expect(before.state.trips[0].driver?.id).toBe(driver.participantId);
  });

  test("invalid and unknown email/password responses are identical and never echo secrets", async () => {
    const t = backend();
    const args = registration();
    await t.action(api.accounts.signUp, args);
    for (const input of [{ email: args.email, password: "wrong password" }, { email: "unknown@example.test", password },
      { email: "not-an-email", password }, { email: args.email, password: 123 }, { email: args.email, password: "s".repeat(129) }]) {
      try {
        await t.action(api.accounts.signIn, input as never);
        expect.fail("Sign-in unexpectedly succeeded");
      } catch (error) {
        expect(error).toMatchObject({ data: { status: 401, message: "Invalid email or password" } });
        expect(String(error)).not.toContain(args.email);
        expect(String(error)).not.toContain(password);
      }
    }
    expect(await t.run(ctx => ctx.db.query("users").collect())).toHaveLength(1);
  });

  test("login attempts are bounded per account and reset only after the window", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    const t = backend();
    const args = registration();
    await t.action(api.accounts.signUp, args);
    const other = registration();
    await t.action(api.accounts.signUp, other);
    for (let i = 0; i < loginLimit; i++) {
      await failure(t.action(api.accounts.signIn, { email: args.email, password: "incorrect password" }), 401, "Invalid email or password");
    }
    await failure(t.action(api.accounts.signIn, { email: args.email.toUpperCase(), password }), 401, "Invalid email or password");
    expect((await t.action(api.accounts.signIn, { email: other.email, password })).account.email).toBe(other.email);
    const user = await t.run(ctx => ctx.db.query("users").withIndex("by_email", q => q.eq("email", args.email)).unique());
    expect(user?.loginAttempts).toBe(loginLimit);
    vi.setSystemTime(user!.loginWindowStart + loginWindow - 1);
    await failure(t.action(api.accounts.signIn, { email: args.email, password }), 401);
    vi.setSystemTime(Date.now() + 1);
    expect((await t.action(api.accounts.signIn, { email: args.email, password })).account.email).toBe(args.email);
  });

  test("concurrent attempts cannot bypass the account login budget", async () => {
    const t = backend();
    const args = registration();
    await t.action(api.accounts.signUp, args);
    const results = await Promise.allSettled(Array.from({ length: loginLimit + 3 }, () =>
      t.action(api.accounts.signIn, { email: args.email, password })));
    expect(results.filter(result => result.status === "fulfilled")).toHaveLength(loginLimit);
    for (const result of results.filter(result => result.status === "rejected")) {
      expect(result).toMatchObject({ reason: { data: { status: 401, message: "Invalid email or password" } } });
    }
    expect((await t.run(ctx => ctx.db.query("users").first()))?.loginAttempts).toBe(loginLimit);
  });

  test("submitted role and identity never replace the stored account", async () => {
    const t = backend();
    const args = registration();
    const rider = await t.action(api.accounts.signUp, args);
    const spoof = { email: args.email, password, role: "driver", userId: "other", name: "Spoofed", online: true };
    const session = await t.action(api.accounts.signIn, spoof);
    expect(session.account).toEqual(rider.account);
    expect(await t.query(api.accounts.profile, { token: rider.token, ...spoof } as never)).toEqual(rider.account);
    await failure(t.mutation(api.dispatch.availability, { token: rider.token, online: true, role: "driver" } as never), 403);
    expect((await t.run(ctx => ctx.db.query("users").first()))?.online).toBe(false);
  });

  test.each([
    { name: " " }, { email: "invalid" }, { password: "short" }, { password: "x".repeat(129) },
    { role: "admin" }, { role: "driver" }, { role: "driver", vehicle: "Car" },
    { role: "driver", vehicle: "Car", plate: "x".repeat(21) }, { serviceArea: "x".repeat(81) },
    { serviceArea: "area/other" }, { serviceArea: "" }, { serviceArea: 123 },
  ])("invalid registration is safely rejected: %j", async overrides => {
    const t = backend();
    await failure(t.action(api.accounts.signUp, registration(overrides)), 400);
    expect(await t.run(ctx => ctx.db.query("users").collect())).toEqual([]);
  });

  test("malformed arguments and tokens return application errors without credential echoes", async () => {
    const t = backend();
    for (const value of [{}, { name: [], email: null, password: 12 }, { name: { secret: "not-a-name" } }]) {
      await failure(t.action(api.accounts.signUp, value as never), 400);
      await failure(t.action(api.accounts.signIn, value as never), 401);
      await failure(t.query(api.accounts.resume, value as never), 401);
      await failure(t.query(api.accounts.profile, value as never), 401);
      await failure(t.mutation(api.accounts.signOut, value as never), 401);
    }
    for (const token of ["secret-short", `user.${"X".repeat(43)}`, null, 123]) {
      for (const call of [t.query(api.accounts.resume, { token } as never), t.query(api.accounts.profile, { token } as never)]) {
        try {
          await call;
          expect.fail("Invalid token unexpectedly succeeded");
        } catch (error) {
          expect(error).toMatchObject({ data: { status: 401 } });
          if (typeof token === "string") expect(String(error)).not.toContain(token);
        }
      }
    }
  });
});
