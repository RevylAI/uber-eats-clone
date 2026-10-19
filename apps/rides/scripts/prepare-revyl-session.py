#!/usr/bin/env python3
import secrets

print("RIDES_AUTH_BYPASS_ENABLED=true")
print("RIDES_AUTH_BYPASS_TOKEN=" + secrets.token_urlsafe(32))
