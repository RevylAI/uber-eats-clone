#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodegen >/dev/null; then
  brew install xcodegen
fi
swift test
swift test -c release
xcodegen generate
xcodebuild build-for-testing -project RidesDemo.xcodeproj -scheme RidesDemo -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
python3 - <<'PY'
import plistlib
import subprocess
from pathlib import Path

info = Path("build/Build/Products/Debug-iphonesimulator/RidesDemo.app/Info.plist")
with info.open("rb") as stream:
    value = plistlib.load(stream)
schemes = [scheme for item in value.get("CFBundleURLTypes", []) for scheme in item.get("CFBundleURLSchemes", [])]
assert "ridesdemo" in schemes, "The built app is missing its Revyl URL scheme"
subprocess.run(["codesign", "--verify", str(info.parent)], check=True)
PY
