import json
import os
from pathlib import Path
import secrets
import stat
import time
from urllib.request import Request, urlopen
import uuid


BACKEND_URL = "https://harmless-mammoth-742.convex.cloud"


def register(role, area):
    account = {
        "name": "Alex Morgan" if role == "rider" else "Jordan Lee",
        "email": role + "-" + uuid.uuid4().hex + "@rides.invalid",
        "password": secrets.token_urlsafe(32),
        "role": role,
        "serviceArea": area,
    }
    if role == "driver":
        account.update(vehicle="Silver Toyota Prius", plate="TX 8248")
    request = Request(
        BACKEND_URL + "/api/action",
        data=json.dumps({"path": "accounts:signUp", "args": account, "format": "json"}).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urlopen(request, timeout=20) as response:
            envelope = json.load(response)
        if envelope.get("status") != "success":
            raise ValueError()
        session = envelope["value"]
        validate_session(session, role)
        return session
    except Exception:
        raise RuntimeError("Couldn't register the Rides test account. Check backend availability.") from None


def validate_session(session, role):
    profile = session["account"]
    if not (
        role in ("rider", "driver")
        and session["role"] == profile["role"] == role
        and session["participantId"] == session["roomCode"] == profile["id"]
        and session["name"] == profile["name"]
        and session["token"].startswith("user.")
        and len(session["token"]) >= 48
        and session["expiresAt"] > time.time() * 1000
    ):
        raise ValueError("Invalid or expired Rides account session")


def account_for(role, accounts_file=None):
    if not accounts_file:
        return register(role, "test-" + uuid.uuid4().hex)
    path = Path(accounts_file).expanduser()
    if path.exists():
        if path.is_symlink() or stat.S_IMODE(path.stat().st_mode) & 0o077:
            raise RuntimeError("The private account file must not be a symlink or readable by other users.")
        try:
            payload = json.loads(path.read_text())
            if payload["backend"] != BACKEND_URL:
                raise ValueError()
            validate_session(payload[role], role)
            return payload[role]
        except Exception:
            raise RuntimeError("The private account file is invalid or expired. Use a new file for fresh accounts.") from None
    area = "test-" + uuid.uuid4().hex
    payload = {"backend": BACKEND_URL, "serviceArea": area, "rider": register("rider", area), "driver": register("driver", area)}
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w") as stream:
        json.dump(payload, stream)
    return payload[role]
