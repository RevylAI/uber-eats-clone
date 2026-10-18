# Progress toward flow parity

This repository starts with an offline restaurant-ordering foundation. The linked Mobbin capture is the design reference, not a claim that every Uber Eats flow is implemented. All services remain local until a separate integration is added.

## Implemented foundation

- [x] Native SwiftUI navigation and bundled photography.
- [x] Local onboarding with an explicit demo verification code.
- [x] Restaurant discovery, cuisine filters, search, favorites, and empty states.
- [x] Restaurant menus, required size selection, optional extras, notes, and quantities.
- [x] Single-restaurant cart with explicit replacement consent.
- [x] Delivery, pickup, scheduling, priority, addresses, and delivery instructions.
- [x] Integer-cent pricing, automatic restaurant offers, promo codes, fees, tax, and tips.
- [x] Demo wallet, membership, profile, and notification preferences.
- [x] Local orders, illustrated tracking, cancellation, ratings, receipts, and reordering.
- [x] Persistence and isolated store regression tests.

## Remaining reference breadth

- [ ] Inventory every flow in the pinned Mobbin version and record screen-by-screen coverage.
- [ ] Grocery and retail catalogs, substitutions, and item-specific modifiers.
- [ ] Group orders and participant state.
- [ ] Gifting and recipient details.
- [ ] Courier conversation and expanded support simulations.
- [ ] Full accessibility, Dynamic Type, regional, and localization verification.
- [ ] Automated UI regression coverage for every mapped journey.

## Later service integration

- [ ] Replace the in-process catalog and order operations behind `AppStore` with a service boundary.
- [ ] Add authenticated identity, secure storage, and account recovery.
- [ ] Add real availability, payment authorization, and idempotent order submission.
- [ ] Add geocoding, maps, courier dispatch, push notifications, and live order updates.

No checkbox authorizes live payments, personal data collection, or merchant integrations. Those require separate implementation, credentials, and verification.
