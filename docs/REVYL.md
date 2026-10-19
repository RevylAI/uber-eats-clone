# Revyl automation and test-only sign-in

`.revyl/config.yaml` binds the repository root to Revyl project `a882d616-7092-471d-a524-0019bb41385e` and iOS app `ecced7bf-9a43-4a8b-9a26-c072fa7bad74` (Uber Eats Clone iOS). The GitHub App has repository access, and this configuration has been published with PR builds and Proof of Changes enabled. A proof is verified only when the corresponding PR report completes successfully.

The `pull-request` build profile runs the same `scripts/build-ios.sh` used for cloud compilation and core tests. Revyl builds a Debug iOS simulator app, then its proof agent exercises the changed behavior plus the declared ordering and navigation invariants. GitHub Actions independently runs `scripts/verify-ios.sh`. Neither path submits real orders or payments.

The build also inspects the packaged app's URL schemes and fails if `eatsclone` is missing. XcodeGen writes its app plist under `.generated/`, separate from the `build/Info.plist` metadata that Xcode creates for Derived Data.

## Test-only session contract

Debug builds accept this custom URL only when the session explicitly enables the gate and supplies its matching, at-least-32-character token:

```text
eatsclone://revyl-auth?token=<session-token>&role=buyer&redirect=/home
```

Only `buyer` and the exact routes `/home`, `/browse`, `/orders`, and `/account` are allowed. Duplicate or unexpected parameters are rejected. A successful request uses the existing local demo profile and persistent onboarding flag; it does not create a remote identity or a real authenticated session. Rejected requests change only the visible debug status, not the profile, onboarding state, or destination.

The native app reads `EATSCLONE_AUTH_BYPASS_ENABLED` and `EATSCLONE_AUTH_BYPASS_TOKEN` from the environment or Revyl's iOS `-KEY value` launch arguments. The handler and status banner are excluded from Release builds with `#if DEBUG`; ordinary Debug launches also reject links unless explicitly enabled. The normal offline onboarding and demo-profile button are separate from this test hook.

`scripts/prepare-revyl-session.py` generates a new cryptographically random token for every checkout-backed device or proof session. Its stdout is Revyl's `KEY=VALUE` secret-transport protocol, not a log to print or retain. The config references the token by name; no token or API key is committed. Revyl resolves the deep link using that session's boot values.

PR preview links have no checkout and cannot execute this script. They instead use the app-specific organization launch variables `EATSCLONE_AUTH_BYPASS_ENABLED=true` and encrypted `EATSCLONE_AUTH_BYPASS_TOKEN`. Those references also need to exist for connected configuration validation. They grant only access to this offline demo's Debug onboarding hook, not production services. Rotate or remove the encrypted fallback if preview access should be revoked; already-booted sessions must be restarted.

## Check the setup

With an authorized Revyl CLI account or a securely configured `REVYL_API_KEY`, run from the repository root:

```sh
revyl config validate
revyl github status --json
```

The repository should report `access_granted: true` and project `status: enabled`. For a manually managed project, `revyl config push` publishes edits. Once the config is reconciled from the default branch, Git becomes authoritative: validate and commit subsequent configuration changes instead of manually publishing over it.

After a preview build is ready, start a fresh session against its version:

```sh
revyl device start --platform ios --build-version-id <preview-version-id> --json
revyl device screenshot --out <screenshot-path>
```

The Home tab should appear without onboarding, with `Revyl sign-in accepted · Local buyer` visible. A wrong-token URL must show a rejected status and must not change the selected destination. `revyl dev auth refresh` reapplies the original valid session link. Restart the session to change boot launch variables; refreshing does not remint or alter them.

After replacing the app binary in a running raw device session, start a fresh prepared session rather than relying on install followed by refresh. The replacement app can launch without the old boot variables and correctly reject the link as disabled.

The regression tests cover allowed routes, environment and iOS arguments, production and missing/disabled gates, absent/short/wrong tokens, forbidden roles and destinations, duplicate parameters, ignored URLs, rejected-state preservation, and normal persistence after acceptance. Run both Debug and Release core tests on a Mac to exercise compile-time exclusion:

```sh
swift test
swift test --configuration release
```

For a fork or a different Revyl organization, create your own project and iOS app, replace both IDs, and create the two organization launch-variable references before validating and publishing. Never copy credentials or session tokens into the repository.
