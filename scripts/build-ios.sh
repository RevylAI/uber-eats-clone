#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodegen >/dev/null; then
  brew install xcodegen
fi
swift test
xcodegen generate
xcodebuild build-for-testing -project EatsClone.xcodeproj -scheme EatsClone -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO
python3 - <<'PY'
import plistlib
from pathlib import Path

info = plistlib.loads(Path("build/Build/Products/Debug-iphonesimulator/EatsClone.app/Info.plist").read_bytes())
schemes = [scheme for entry in info.get("CFBundleURLTypes", []) for scheme in entry.get("CFBundleURLSchemes", [])]
print("Built app URL schemes:", schemes)
if "eatsclone" not in schemes:
    raise SystemExit("The built app is missing its Revyl auth-bypass URL scheme")
PY
