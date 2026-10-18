# Verification

## 2026-10-18: Revyl cloud build

Build `01M58EBQX8M1CCVWEJ3FAV2BJC` succeeded on Revyl's macOS runner using `bash scripts/build-ios.sh`.

- Swift Package Manager executed 10 `AppStoreTests` with zero failures.
- Xcode compiled the native iOS app and its iOS test bundle for the simulator with `build-for-testing`.
- The build produced `EatsClone.app` and uploaded it as the current cloud build.

The store tests cover cart merging and customization, replacement consent, quantity removal, integer-cent checkout calculations, membership and offers, order snapshots and persistence, terminal tracking states, cancellation and reorder consent, invalid checkout guards, and reset/favorites persistence.

This is not a claim that iOS XCTest execution passed: the runner had no configured iPhone simulator, so store tests ran on macOS and the iOS test bundle was compiled only. The initial simulator-test attempt stopped at simulator discovery before compilation. Cloud-phone runtime verification is recorded separately when available.
