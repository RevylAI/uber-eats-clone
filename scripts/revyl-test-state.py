#!/usr/bin/env python3
"""Fake test-state provider for Revyl proof runs.

describe  prints the settable client flags, backend flags and user states.
finalize  "creates" a test user in the requested state and prints a
          short-lived sign-in link plus the launch values the app needs.

This stands in for a real user service. A real provider would call its
backend with STATE_PROVIDER_API_TOKEN; this one only reports whether that
credential reached the shell, never its value.
"""
import argparse
import json
import os
import secrets
import sys
import time
import uuid
from urllib.parse import urlencode

CLIENT_FLAGS = {
    "EATSCLONE_FLAG_PASS_BADGE": {
        "values": ["on", "off"],
        "default": "off",
        "doc": "Client flag. Shows the Eats Pass card on Home for Eats Pass members. Pass it to the app with --launch-env.",
    },
}

BACKEND_FLAGS = {
    "free_delivery": {
        "values": ["on", "off"],
        "default": "off",
        "doc": "Server flag. Waives the delivery fee for Eats Pass members. Set it on the user with finalize --flag.",
    },
}

USER_STATES = {
    "new_user": {"tier": "standard", "doc": "Fresh account, no orders, no membership."},
    "returning_buyer": {"tier": "standard", "doc": "Has past orders, no membership."},
    "eats_pass_member": {"tier": "eats_pass", "doc": "Active Eats Pass subscription."},
}

TOKEN_TTL_SECONDS = 600


def describe():
    print(json.dumps({
        "client_flags": CLIENT_FLAGS,
        "backend_flags": BACKEND_FLAGS,
        "user_states": USER_STATES,
        "finalize": "finalize --state <user_state> [--flag <backend_flag>=<value> ...]",
    }, indent=2))


def finalize(state, flag_args):
    if state not in USER_STATES:
        sys.exit(f"Unknown state {state!r}. Run describe for the allowed states.")
    flags = {name: spec["default"] for name, spec in BACKEND_FLAGS.items()}
    for item in flag_args:
        name, _, value = item.partition("=")
        if name not in BACKEND_FLAGS or value not in BACKEND_FLAGS[name]["values"]:
            sys.exit(f"Invalid backend flag {item!r}. Run describe for the allowed flags.")
        flags[name] = value

    token = secrets.token_urlsafe(32)
    print(json.dumps({
        "user_id": "poc-" + uuid.uuid4().hex[:12],
        "state": state,
        "backend_flags": flags,
        "credential": "present" if os.environ.get("STATE_PROVIDER_API_TOKEN") else "absent",
        "expires_at": int(time.time()) + TOKEN_TTL_SECONDS,
        "app_link": "eatsclone://revyl-auth?" + urlencode({"token": token, "role": "buyer", "redirect": "/home"}),
        "launch_env": [
            "EATSCLONE_AUTH_BYPASS_ENABLED=true",
            "EATSCLONE_AUTH_BYPASS_TOKEN=" + token,
            "EATSCLONE_ACCOUNT_TIER=" + USER_STATES[state]["tier"],
            "EATSCLONE_SERVER_FREE_DELIVERY=" + flags["free_delivery"],
        ],
    }, indent=2))


parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
commands = parser.add_subparsers(dest="command", required=True)
commands.add_parser("describe")
finalize_parser = commands.add_parser("finalize")
finalize_parser.add_argument("--state", required=True)
finalize_parser.add_argument("--flag", action="append", default=[])
args = parser.parse_args()
if args.command == "describe":
    describe()
else:
    finalize(args.state, args.flag)
