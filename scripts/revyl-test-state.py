#!/usr/bin/env python3
"""describe  prints the settable client flags, backend flags and user states.
finalize  creates a test user and prints a short-lived sign-in link and launch values.
"""
import argparse
import json
import os
import sys
from urllib.parse import urlencode

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_state import catalog, create_user

parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
commands = parser.add_subparsers(dest="command", required=True)
commands.add_parser("describe")
finalize_parser = commands.add_parser("finalize")
finalize_parser.add_argument("--state", required=True)
finalize_parser.add_argument("--flag", action="append", default=[], help="backend_flag=value")
args = parser.parse_args()

if args.command == "describe":
    print(json.dumps({
        **catalog(),
        "state_request": 'STATE_REQUEST=\'{"state": "<user_state>", "backend_flags": {"<name>": "<value>"}, "client_flags": {"<NAME>": "<value>"}}\' revyl device start ...',
        "finalize": "finalize --state <user_state> [--flag <backend_flag>=<value> ...]",
    }, indent=2))
    raise SystemExit(0)

try:
    user, token, launch_env = create_user(args.state, dict(item.partition("=")[::2] for item in args.flag))
except ValueError as error:
    sys.exit(f"{error}. Run describe for the allowed values.")
print(json.dumps({
    **user,
    "app_link": "eatsclone://revyl-auth?" + urlencode({"token": token, "role": "buyer", "redirect": "/home"}),
    "launch_env": [f"{key}={value}" for key, value in launch_env.items()],
}, indent=2))
