# Verification

## 2026-10-18: Revyl configuration and test-only sign-in

Build `01M58JB7XGCMM26PCN6CWQ4QA7` succeeded after correcting the build recipe to invoke the non-executable script with `bash`.

- All 20 core tests passed in both Debug and Release on the cloud macOS runner, including 10 new sign-in bypass regression tests.
- The Debug iOS app and iOS test bundle compiled successfully; iOS XCTest execution is not established by this build.
- Revyl connected configuration validation succeeded. The repository-root configuration was published, and `revyl github status --json` reported repository access granted and project status enabled.
- Session-preparation checks confirmed independent, sufficiently long random tokens and the expected protocol keys without retaining or displaying token values.

These checks do not establish that sign-in works on a cloud iPhone or that an automatic PR proof has completed. Those require a device session and an actual PR report respectively.

## 2026-10-18: Revyl cloud build

Builds `01M58EBQX8M1CCVWEJ3FAV2BJC` and `01M58EY9CZ4T32J1XPGR1R07R9` succeeded on Revyl's macOS runner using `bash scripts/build-ios.sh`. The latter includes the device-discovered cart-navigation correction.

- Swift Package Manager executed 10 `AppStoreTests` with zero failures.
- Xcode compiled the native iOS app and its iOS test bundle for the simulator with `build-for-testing`.
- The build produced `EatsClone.app` and uploaded it as the current cloud build.

The store tests cover cart merging and customization, replacement consent, quantity removal, integer-cent checkout calculations, membership and offers, order snapshots and persistence, terminal tracking states, cancellation and reorder consent, invalid checkout guards, and reset/favorites persistence.

This is not a claim that iOS XCTest execution passed: the runner had no configured iPhone simulator, so store tests ran on macOS and the iOS test bundle was compiled only. The initial simulator-test attempt stopped at simulator discovery before compilation. Cloud-phone runtime verification is recorded separately when available.

## Cloud-phone checks

The app was installed and exercised on a Revyl cloud iPhone. The following interactions were observed through the rendered UI:

- Local onboarding, invalid-code feedback, demo code entry, profile name, and address setup.
- Cuisine filtering from the home feed and saving a restaurant as a favorite.
- Opening a menu item, required size selection, an optional extra, and quantity changes.
- Adding two customized burgers, opening the cart, and navigating to checkout.
- Applying `WELCOME`: the $24.78 total changed to $19.78, including the automatic $11.95 restaurant offer.
- Confirming a local order and opening its tracking sheet.
- Advancing through preparing, on-the-way, and delivered; saving a five-star rating.
- Viewing order history and the receipt, then reordering into a new cart.

Device testing also exposed the cart bar covering the tab bar. The cart inset was moved inside each tab's navigation container. The follow-up build was installed on a cloud iPhone, a new item was added, and the cart bar and all four tabs were visibly separate. Switching to Account with a nonempty cart succeeded. Menu item accessibility labels were also verified to appear once rather than repeating.

These are manual smoke checks, not an exhaustive UI test suite or a pixel-parity measurement. Grocery, group orders, and gifting remain on the roadmap.
