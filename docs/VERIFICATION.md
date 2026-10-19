# Verification

## 2026-10-18: Repository-bound Revyl CLI verification

The published `pull-request` profile built successfully through the authenticated Revyl CLI as job `cfcf8d4a-3205-46da-aa10-b4ed8955629c`, uploading version `fd1f7840-b904-43ac-bc43-066a7aaa639d` to the configured Uber Eats Clone iOS app. This independently verifies the actual repository-bound recipe, rather than only a separate Capy build.

Cloud-device testing exposed an app-plist collision: Xcode replaced `build/Info.plist` with Derived Data metadata, removing the custom URL scheme. The generated application plist now lives at `.generated/EatsClone-Info.plist`, and the build checks the final packaged plist for `eatsclone` before uploading.

The final app was exercised on a Revyl cloud iPhone:

- A fresh session executed session preparation, opened the tokenized link, skipped onboarding, and displayed `Revyl sign-in accepted · Local buyer` on Home.
- A wrong-token link requesting Account was rejected, leaving Home visible.
- Refreshing the link with the original hidden boot token but role `admin` was visibly rejected.
- Refreshing with the original hidden token but redirect `/admin` was visibly rejected.
- Replacing the app in a running raw session dropped its launch gate; the app visibly rejected the next link as disabled. A fresh prepared session restored successful sign-in.
- The final accepted and rejected status banners were visually inspected and checked against the accessibility hierarchy to confirm that neither overlaps the address header.
- After automatic sign-in, one Regular Super Burger was added to the cart and Home was reopened. The cart button and all four tabs were visually separate; switching to Account with the nonempty cart succeeded.

[Accepted sign-in screenshot](https://api-staging.capy.ai/pr-assets/yKV4MObZr7r_eQ0UVQ4_nvIZnYiv9fgc98zSm9qYf3c.png) · [Rejected sign-in screenshot](https://api-staging.capy.ai/pr-assets/I__fdkI4M79oaGDpqbra9bpOkIZAIYAk_YUUE0xo1oQ.png)

[Signed-in cart and tab navigation screenshot](https://api-staging.capy.ai/pr-assets/RwJAsVX2dHu8LbhPOLW2nWXEYtKS0t43nqsmk7tdfvM.png)

The final recipe also passed its 20 Debug core tests and compiled the iOS app/test bundle. Release core regression coverage is recorded below. An actual automatic PR Proof of Changes run remains unverified; these manual device checks are not a substitute for its PR report.

## 2026-10-18: Revyl configuration and test-only sign-in

Build `01M58JB7XGCMM26PCN6CWQ4QA7` succeeded after correcting the build recipe to invoke the non-executable script with `bash`.

- All 20 core tests passed in both Debug and Release on the cloud macOS runner, including 10 new sign-in bypass regression tests.
- The Debug iOS app and iOS test bundle compiled successfully; iOS XCTest execution is not established by this build.
- Revyl connected configuration validation succeeded. The repository-root configuration was published, and `revyl github status --json` reported repository access granted and project status enabled.
- Session-preparation checks confirmed independent, sufficiently long random tokens and the expected protocol keys without retaining or displaying token values.

These build-time checks alone do not establish on-device behavior or an automatic PR proof. The later cloud-iPhone follow-up is recorded above; an automatic PR proof still requires an actual PR report.

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
