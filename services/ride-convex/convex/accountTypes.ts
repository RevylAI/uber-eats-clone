import type { Infer } from "convex/values";
import type { trip } from "./schema";

export type Account = {
  id: string; name: string; email: string; role: "rider" | "driver";
  vehicle: string | null; plate: string | null;
};
export type AccountState = {
  roomCode: string; revision: number; driverOnline: boolean;
  onlineDriverIds: string[]; trips: Infer<typeof trip>[];
};
export type AccountSession = {
  roomCode: string; participantId: string; token: string; role: "rider" | "driver";
  name: string; state: AccountState; account: Account; expiresAt: number;
};
export type SignUp = {
  name: string; email: string; password: string; role: string;
  vehicle?: string; plate?: string; serviceArea?: string;
};
export type SignIn = { email: string; password: string };
