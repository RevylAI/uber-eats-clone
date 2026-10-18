#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodegen >/dev/null; then
  brew install xcodegen
fi
xcodegen generate
DEVICE_ID=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; data=json.load(sys.stdin); print(next((d["udid"] for runtime, devices in data["devices"].items() if "iOS" in runtime for d in devices if "iPhone" in d["name"]), ""))')
if [ -z "$DEVICE_ID" ]; then
  echo 'No available iPhone simulator. Install an iOS runtime in Xcode, or use scripts/build-ios.sh for cloud compilation and macOS store tests.' >&2
  exit 1
fi
xcodebuild test -project EatsClone.xcodeproj -scheme EatsClone -destination "platform=iOS Simulator,id=$DEVICE_ID" -derivedDataPath build -resultBundlePath build/Tests.xcresult CODE_SIGNING_ALLOWED=NO
