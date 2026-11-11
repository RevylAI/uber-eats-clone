"""Shared catalog and fake user service for Revyl proof test state.

A real provider would call its user service here with STATE_PROVIDER_API_TOKEN.
This one fabricates the user locally and only reports whether that credential
reached the process, never its value.
"""
import hashlib
import json
import os
import secrets
import time
import uuid
from pathlib import Path

CLIENT_FLAGS = {
    "EATSCLONE_FLAG_PASS_BADGE": {
        "values": ["on", "off"],
        "default": "off",
        "doc": "Client flag. Shows the Eats Pass card on Home for Eats Pass members.",
    },
}

BACKEND_FLAGS = {
    "free_delivery": {
        "values": ["on", "off"],
        "default": "off",
        "doc": "Server flag. Waives the delivery fee for Eats Pass members.",
    },
}

USER_STATES = {
    "new_user": {"tier": "standard", "doc": "Fresh account, no orders, no membership."},
    "returning_buyer": {"tier": "standard", "doc": "Has past orders, no membership."},
    "eats_pass_member": {"tier": "eats_pass", "doc": "Active Eats Pass subscription."},
}

TOKEN_TTL_SECONDS = 600
AUDIT_LOG = Path(__file__).resolve().parents[1] / ".revyl" / "state-provider-audit.log"


def catalog():
    return {"client_flags": CLIENT_FLAGS, "backend_flags": BACKEND_FLAGS, "user_states": USER_STATES}


def _checked(name, value, allowed, kind):
    if value not in allowed:
        raise ValueError(f"Invalid {kind} {name}={value!r}. Allowed: {sorted(allowed)}")
    return value


def create_user(state, backend_flags=None, client_flags=None):
    _checked("state", state, USER_STATES, "user state")
    server = {name: spec["default"] for name, spec in BACKEND_FLAGS.items()}
    for name, value in (backend_flags or {}).items():
        server[name] = _checked(name, value, BACKEND_FLAGS.get(name, {}).get("values", []), "backend flag")
    client = {}
    for name, value in (client_flags or {}).items():
        client[name] = _checked(name, value, CLIENT_FLAGS.get(name, {}).get("values", []), "client flag")

    token = secrets.token_urlsafe(32)
    user = {
        "user_id": "poc-" + uuid.uuid4().hex[:12],
        "state": state,
        "backend_flags": server,
        "client_flags": client,
        "credential": "present" if os.environ.get("STATE_PROVIDER_API_TOKEN") else "absent",
        "expires_at": int(time.time()) + TOKEN_TTL_SECONDS,
    }
    AUDIT_LOG.parent.mkdir(exist_ok=True)
    with AUDIT_LOG.open("a") as log:
        log.write(json.dumps({**user, "token_sha256_prefix": hashlib.sha256(token.encode()).hexdigest()[:12]}) + "\n")
    launch_env = {
        "EATSCLONE_AUTH_BYPASS_ENABLED": "true",
        "EATSCLONE_AUTH_BYPASS_TOKEN": token,
        "EATSCLONE_ACCOUNT_TIER": USER_STATES[state]["tier"],
        "EATSCLONE_SERVER_FREE_DELIVERY": server["free_delivery"],
        **client,
    }
    return user, token, launch_env
