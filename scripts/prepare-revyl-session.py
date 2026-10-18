#!/usr/bin/env python3
import secrets

print("EATSCLONE_AUTH_BYPASS_ENABLED=true")
print("EATSCLONE_AUTH_BYPASS_TOKEN=" + secrets.token_urlsafe(32))
