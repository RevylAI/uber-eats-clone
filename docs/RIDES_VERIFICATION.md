# Rides verification

This document distinguishes compilation, automated tests, and the requested paired-phone behavior. No real ride, charge, call, or location tracking is performed.

## Completed before paired-phone verification

- `services/ride-demo`: six HTTP integration tests pass on Node 24, including rider/driver visibility, exclusive concurrent acceptance, idempotency, room isolation, assignment/role checks, chat, cancellation, immediate scheduling, duplicate route rejection, and SQLite restart persistence.
- Rides cloud build `01M58ZZR2QFH9KEAWV81B5R0J9` succeeded, version `39c4375d-9d9d-4526-bc81-80bde777669a`. The build runs Debug/Release Swift core tests, compiles the native app and its test bundle, and asserts the packaged `ridesdemo` URL scheme.
- Repository-root Revyl `rides` profile uploaded build `c2f0041d-c937-44bc-9333-b9b199ec2ff3` to app `1f375e45-bf9b-434a-b939-a8892a2297c3`; this is distinct from the Capy-managed verification build.
- Both root build profiles pass connected `revyl config validate`. The new profile is not published from `main` until its PR merges. Existing Eats application code and sign-in defaults are unchanged.

## Outstanding gates

- On-device rider booking → second-phone driver request → driver acceptance → rider assignment confirmation, with screenshots.
- On-device progress, chat, completion/rating, and cancellation coverage.
- The Debug role launcher and rejection cases on a fresh rides device session.
- iOS simulator XCTest execution. One cloud compilation attempt built successfully but could not execute the simulator tests because that runner had no installed iPhone runtime. macOS core tests and `build-for-testing` are not a simulator test pass.
- Persistent service deployment for demos outside the active verification workspace.

The full Uber release inventory and exhaustive reference parity have not been established. Automatic Revyl Proof of Changes remains configured for Eats rather than the paired-phone rides scenario.
