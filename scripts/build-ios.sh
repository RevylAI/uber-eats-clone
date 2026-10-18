#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodegen >/dev/null; then
  brew install xcodegen
fi
swift test
xcodegen generate
xcodebuild build-for-testing -project EatsClone.xcodeproj -scheme EatsClone -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO
