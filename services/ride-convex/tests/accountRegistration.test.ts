// @vitest-environment node
import { convexTest } from "convex-test";
import { expect, test } from "vitest";
import { api } from "../convex/_generated/api";
import schema from "../convex/schema";

const modules = import.meta.glob("../convex/**/*.ts");
const nullableFields = [{ vehicle: null }, { plate: null }, { vehicle: null, plate: null }];

test.each(nullableFields)("rider registration accepts JSON null for absent vehicle details: %j", async fields => {
  const t = convexTest({ schema, modules, transactionLimits: true });
  const email = `${crypto.randomUUID()}@example.test`;
  const password = "native registration fixture";
  const session = await t.action(api.accounts.signUp, {
    name: "Taylor", email, password, role: "rider", ...fields,
  });
  expect(session.account).toMatchObject({ name: "Taylor", email, role: "rider", vehicle: null, plate: null });
  expect((await t.action(api.accounts.signIn, { email, password })).account).toEqual(session.account);
  expect((await t.query(api.accounts.resume, { token: session.token })).account).toEqual(session.account);
});

test.each(nullableFields)("driver registration still requires non-null vehicle details: %j", async fields => {
  const t = convexTest({ schema, modules, transactionLimits: true });
  await expect(t.action(api.accounts.signUp, {
    name: "Taylor", email: `${crypto.randomUUID()}@example.test`, password: "native registration fixture",
    role: "driver", vehicle: "Silver sedan", plate: "TX 1234", ...fields,
  })).rejects.toMatchObject({ data: { status: 400 } });
  expect(await t.run(ctx => ctx.db.query("users").collect())).toEqual([]);
});
