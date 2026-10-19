#!/usr/bin/env python3
import secrets
import sys

from revyl_accounts import account_for


def main():
    try:
        session = account_for("rider")
    except Exception:
        print("Couldn't prepare the Rides account. Check backend availability.", file=sys.stderr)
        return 1
    print("RIDES_AUTH_BYPASS_ENABLED=true")
    print("RIDES_AUTH_BYPASS_TOKEN=" + secrets.token_urlsafe(32))
    print("RIDES_ACCOUNT_SESSION=" + session["token"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
