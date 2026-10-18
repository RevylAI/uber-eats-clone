# EatsClone

An independent, self-contained food delivery demo built with native SwiftUI for iOS 17 and later. Its interaction design is inspired by the Uber Eats references on Mobbin. This project is not affiliated with, endorsed by, or connected to Uber, Uber Eats, Mobbin, Unsplash, or any restaurant shown in its sample catalog.

The initial release focuses on a local restaurant-ordering journey: onboarding, discovery, menus, item customization, cart, demo checkout, simulated order progress, and saved account data. This is not yet a complete reproduction of Uber Eats. See [scope and limitations](docs/PARITY.md), the [parity roadmap](docs/ROADMAP.md), and [design references](docs/REFERENCES.md).

## Run on an iOS simulator

Use a Mac with Xcode 15 or later, an installed iOS 17-or-later simulator runtime, and [XcodeGen](https://github.com/yonaskolb/XcodeGen). From the repository root:

```sh
brew install xcodegen
xcodegen generate
xcodebuild \
  -project EatsClone.xcodeproj \
  -scheme EatsClone \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build
```

The build command compiles for the simulator; it does not launch the app. Open `EatsClone.xcodeproj`, select the `EatsClone` scheme and an available iOS simulator, then choose Run. `project.yml` is the XcodeGen project definition. No API keys, backend server, or account are needed for the demo.

The Revyl cloud build and 10 store tests passed on 2026-10-18. See [verification evidence and its limits](docs/VERIFICATION.md); compilation alone does not establish UI or full feature parity.

`bash scripts/build-ios.sh` runs the store tests on macOS using Swift Package Manager and compiles the iOS app and test bundle without requiring a booted simulator. `bash scripts/verify-ios.sh` also runs the iOS test bundle on an installed iPhone simulator; GitHub Actions uses that command.

## Local data, not live services

The backend substitute is an in-process Swift store. It encodes its snapshot as JSON in `UserDefaults` under `eats.local.snapshot.v1`, preserving the demo profile, favorites, cart, order history, and onboarding flag on the same installation. Other checkout selections are session state. This is not a remote backend, database service, or secure credential store.

Restaurant data, prices, fees, delivery estimates, payment labels, promotions, and order progress are illustrative. Checkout creates a local order only: no real authentication, payment processing, map or geocoding service, restaurant submission, courier dispatch, or delivery takes place. Do not enter real payment details or sensitive personal information. Photos are bundled in the asset catalog, with no runtime image downloads.

For a fresh local demo, pass `--reset-demo` in the scheme's Run arguments or reinstall the app. Resetting removes the local demo snapshot; it does not affect any external account.

## Revyl pull-request verification

The repository includes a published Revyl project configuration for automatic iOS preview builds and Proof of Changes. Its `pull-request` profile runs `scripts/build-ios.sh`; no GitHub Actions API key is required for Revyl-managed builds. See [Revyl setup and test-only sign-in](docs/REVYL.md) for session preparation, security boundaries, and verification commands. Configuration being enabled is not evidence that an individual proof passed; check that pull request's Revyl report.

## License and media

Source code is open source under the [MIT License](LICENSE). The bundled food photographs are separate third-party works covered by the [Unsplash License](https://unsplash.com/license), **not MIT**. [Photo sources and licensing](docs/PHOTOGRAPHY.md) lists every bundled image and its source URL.

Mobbin screenshots and Uber logos are not bundled or licensed by this repository. Product and restaurant names are used only as references or sample content; their trademarks belong to their respective owners. Food photos are illustrative and do not depict or endorse the named restaurants' actual dishes.
