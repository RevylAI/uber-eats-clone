/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as accountActions from "../accountActions.js";
import type * as accountAuth from "../accountAuth.js";
import type * as accountStore from "../accountStore.js";
import type * as accountTypes from "../accountTypes.js";
import type * as accounts from "../accounts.js";
import type * as dispatch from "../dispatch.js";
import type * as dispatchState from "../dispatchState.js";
import type * as rides from "../rides.js";
import type * as validation from "../validation.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  accountActions: typeof accountActions;
  accountAuth: typeof accountAuth;
  accountStore: typeof accountStore;
  accountTypes: typeof accountTypes;
  accounts: typeof accounts;
  dispatch: typeof dispatch;
  dispatchState: typeof dispatchState;
  rides: typeof rides;
  validation: typeof validation;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {};
