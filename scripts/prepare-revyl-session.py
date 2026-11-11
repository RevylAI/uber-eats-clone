#!/usr/bin/env python3
"""session.before_script: mint the sign-in token, optionally for a requested test state.

Without STATE_REQUEST this keeps the default contract: a fresh buyer token.
With STATE_REQUEST='{"state": ..., "backend_flags": {...}, "client_flags": {...}}'
in the environment of `revyl device start`, it creates a test user in that state
and prints the launch values for it. stdout is Revyl's KEY=VALUE secret transport.
"""
import json
import os
import secrets
import sys

request = os.environ.get("STATE_REQUEST")
if not request:
    print("EATSCLONE_AUTH_BYPASS_ENABLED=true")
    print("EATSCLONE_AUTH_BYPASS_TOKEN=" + secrets.token_urlsafe(32))
    raise SystemExit(0)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_state import create_user

try:
    spec = json.loads(request)
    _, _, launch_env = create_user(spec["state"], spec.get("backend_flags"), spec.get("client_flags"))
except (ValueError, KeyError, TypeError) as error:
    print(f"STATE_REQUEST rejected: {error}", file=sys.stderr)
    raise SystemExit(2)
for key, value in launch_env.items():
    print(f"{key}={value}")
