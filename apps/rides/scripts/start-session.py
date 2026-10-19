#!/usr/bin/env python3
import argparse
import json
import os
import secrets
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlencode

from revyl_accounts import account_for

parser = argparse.ArgumentParser(description="Start an isolated Revyl rider or driver session without changing Eats defaults.")
parser.add_argument("--role", choices=["rider", "driver"], default="rider")
parser.add_argument("--build-version-id")
parser.add_argument("--accounts-file", help="Private JSON file for a freshly registered rider/driver pair; created with mode 0600 if absent")
args = parser.parse_args()

root = Path(__file__).resolve().parents[1]
try:
    session = account_for(args.role, args.accounts_file)
    lines = (root / ".revyl/config.yaml").read_text().splitlines()
    app_id = next(line.split(":", 1)[1].strip() for line in lines if line.strip().startswith("app_id:"))
except Exception:
    print("Couldn't prepare the Rides account or app configuration. Account data is withheld.", file=sys.stderr)
    raise SystemExit(1)

token = secrets.token_urlsafe(32)
link = "ridesdemo://revyl-auth?" + urlencode({"token": token, "role": args.role, "redirect": "/home"})
command = [
    "revyl", "device", "start", "--platform", "ios",
    "--app-id", app_id,
    "--no-inherited-launch-vars",
    "--launch-env", "RIDES_AUTH_BYPASS_ENABLED=true",
    "--launch-env", "RIDES_AUTH_BYPASS_TOKEN=" + token,
    "--launch-env", "RIDES_ACCOUNT_SESSION=" + session["token"],
    "--app-link", link, "--timeout", "1800", "--open=false", "--json",
]
if args.build_version_id:
    command += ["--build-version-id", args.build_version_id]
environment = os.environ.copy()
result = subprocess.run(command, cwd=root, env=environment, capture_output=True, text=True)
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
