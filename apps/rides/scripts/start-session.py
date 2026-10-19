#!/usr/bin/env python3
import argparse
import json
import secrets
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlencode, urlparse

parser = argparse.ArgumentParser(description="Start an isolated Revyl rider or driver session without changing Eats defaults.")
parser.add_argument("--role", choices=["rider", "driver"], default="rider")
parser.add_argument("--build-version-id")
parser.add_argument("--server")
parser.add_argument("--room")
args = parser.parse_args()
if args.server:
    parsed = urlparse(args.server)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment or parsed.path not in ("", "/"):
        parser.error("--server must be an HTTPS address without a path or credentials")
if args.room and (not args.server or not args.room.isascii() or not args.room.isalnum() or not 8 <= len(args.room) <= 32):
    parser.error("--room needs --server and an 8–32 character invitation code")

token = secrets.token_urlsafe(32)
link = "ridesdemo://revyl-auth?" + urlencode({"token": token, "role": args.role, "redirect": "/home"})
command = [
    "revyl", "device", "start", "--platform", "ios",
    "--app-id", "1f375e45-bf9b-434a-b939-a8892a2297c3",
    "--launch-env", "RIDES_AUTH_BYPASS_ENABLED=true",
    "--launch-env", "RIDES_AUTH_BYPASS_TOKEN=" + token,
    "--app-link", link, "--timeout", "1800", "--open=false", "--json",
]
if args.build_version_id:
    command += ["--build-version-id", args.build_version_id]
if args.server:
    command += ["--launch-env", "RIDE_DEMO_BASE_URL=" + args.server]
if args.room:
    command += ["--launch-env", "RIDE_DEMO_ROOM_CODE=" + args.room.upper()]

root = Path(__file__).resolve().parents[3]
result = subprocess.run(command, cwd=root, capture_output=True, text=True)
if result.returncode:
    print("Revyl could not start the rides session. Raw output is withheld because it may contain launch credentials. Inspect device availability with `revyl device list`.", file=sys.stderr)
    raise SystemExit(result.returncode)
try:
    payload = json.loads(result.stdout)
except json.JSONDecodeError:
    print("Revyl started but returned unexpected output. Inspect `revyl device list`; raw output is withheld to protect launch credentials.", file=sys.stderr)
    raise SystemExit(1)
safe = {key: payload[key] for key in ("session_id", "workflow_run_id", "index", "platform", "status", "device_model") if key in payload}
safe["role"] = args.role
print(json.dumps(safe, indent=2))
