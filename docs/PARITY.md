# Scope and parity

EatsClone implements a narrow, self-contained restaurant-ordering demo inspired by the linked Uber Eats iOS flows. It is not a feature-complete Uber Eats client, and it does not connect to Uber's services. A screen or local setting resembling a real feature does not provide that feature's live service.

## Core local-demo scope

The restaurant journey covers browsing a bundled sample catalog, viewing menus, customizing items, building a single-restaurant cart, reviewing demo checkout totals, and placing a local order. Supporting flows cover a demo profile and address, favorites, order history, simulated order stages, cancellation of a confirmed order, rating, and reordering.

The store implements cart quantities and options, a cross-restaurant replacement guard, integer-cent totals, illustrative tax and service fees, delivery versus pickup calculations, a priority fee, and the sample `WELCOME` promotion. These are demo business rules, not Uber Eats pricing or eligibility rules. Payment and membership selections are local demonstrations only.

The persisted JSON snapshot in `UserDefaults` holds the profile, favorites, cart, orders, and onboarding state. It is local to an installation, with no synchronization, remote identity, or production durability guarantees. Food images and the sample catalog are bundled; the demo does not depend on runtime photo requests.

## Simulated or excluded integrations

| Area | Demo behavior and limitation |
| --- | --- |
| Authentication | Local profile/onboarding only; no identity verification, sign-in service, OAuth, SMS, or account recovery. |
| Payments | Sample labels and calculated totals only; no card tokenization, payment authorization, charge, refund, or wallet integration. |
| Restaurants | Static sample catalog; no live menus, inventory, business hours, availability, or merchant order submission. |
| Address and maps | Local address text and any illustrative tracking UI; no geocoding, real map service, GPS routing, or location permission workflow. |
| Delivery and pickup | Local order records and simulated progress; no courier, dispatch, real ETA, pickup reservation, or fulfillment. |
| Scheduling and priority | Demo selections and fee calculation where supported; no scheduled job, capacity check, or real priority service. |
| Promotions and membership | Demonstration state and arithmetic; no redemption backend, paid subscription, or entitlement validation. |
| Notifications and support | Any preference or support UI is local; no push service, courier chat, live agent, or operational support system. |

## Uber Eats breadth not implemented

Grocery and retail shopping, rides, group orders, gifts, real authentication, merchant tooling, courier tooling, live customer support, advertising, loyalty systems, and the full range of account, safety, accessibility, localization, and regional checkout variants are outside this implementation. A category, title, or familiar navigation pattern is not evidence of those features.

## Verification boundary

This document describes implementation scope, not tested feature parity. It does not assert that a simulator, device, or cloud build passed, that every interaction was exercised, or that visual parity was measured. Build and runtime evidence must be gathered separately, and any known failures should be reported alongside that evidence.
