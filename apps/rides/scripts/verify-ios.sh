#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build-ios.sh
DEVICE_ID=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; device=next((d["udid"] for group in json.load(sys.stdin)["devices"].values() for d in group if "iPhone" in d["name"]), None); device or sys.exit("No available iPhone simulator. Install an iOS Simulator runtime in Xcode before running simulator tests."); print(device)')
xcodebuild test-without-building -project RidesDemo.xcodeproj -scheme RidesDemo -destination "platform=iOS Simulator,id=$DEVICE_ID" -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
