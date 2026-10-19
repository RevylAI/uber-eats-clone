import type { Doc } from "./_generated/dataModel";
import type { MutationCtx, QueryCtx } from "./_generated/server";
import { limits } from "./validation";

export async function advanceArea(ctx: MutationCtx, name: string) {
  const area = await ctx.db.query("dispatchAreas").withIndex("by_name", q => q.eq("name", name)).unique();
  if (area) await ctx.db.patch(area._id, { revision: area.revision + 1 });
  else await ctx.db.insert("dispatchAreas", { name, revision: 1 });
}

export async function accountState(ctx: QueryCtx | MutationCtx, user: Doc<"users">) {
  const area = await ctx.db.query("dispatchAreas").withIndex("by_name", q => q.eq("name", user.serviceArea)).unique();
  const history = user.role === "rider"
    ? await ctx.db.query("dispatchTrips").withIndex("by_rider", q => q.eq("riderId", user._id)).order("desc").take(limits.trips)
    : await ctx.db.query("dispatchTrips").withIndex("by_driver", q => q.eq("driverId", user._id)).order("desc").take(limits.trips);
  if (user.activeTripId && !history.some(row => row._id === user.activeTripId)) {
    const active = await ctx.db.get(user.activeTripId);
    if (active && (user.role === "rider" ? active.riderId === user._id : active.driverId === user._id)) {
      if (history.length === limits.trips) history.pop();
      history.push(active);
    }
  }
  const offers = user.role === "driver"
    ? await ctx.db.query("dispatchTrips").withIndex("by_area_status", q => q.eq("serviceArea", user.serviceArea).eq("status", "requested"))
      .order("desc").take(limits.trips)
    : [];
  const online = await ctx.db.query("users").withIndex("by_area_role_online", q =>
    q.eq("serviceArea", user.serviceArea).eq("role", "driver").eq("online", true)).take(limits.participants);
  const onlineDriverIds = online.map(driver => driver._id);
  if (user.role === "driver" && user.online && !onlineDriverIds.includes(user._id)) {
    if (onlineDriverIds.length === limits.participants) onlineDriverIds.pop();
    onlineDriverIds.push(user._id);
  }
  return {
    roomCode: user._id, revision: area?.revision ?? 0, driverOnline: onlineDriverIds.length > 0, onlineDriverIds,
    trips: [...history, ...offers].sort((a, b) => b._creationTime - a._creationTime).map(row => row.payload),
  };
}
