## Changes

Describe the shipped behavior and identify whether Eats, Rides, or both are affected.

## Validation

List the checks actually run and their results. Distinguish compilation, executed simulator tests, automatic Proof of Changes, and manual device checks. State failures and coverage gaps.

## Revyl device context and evidence

If a Revyl device was used during development or verification, complete this section in the PR description. Otherwise, state that no Revyl device was used.

- **Source and build:** commit SHA, app/profile, and exact build/version ID. Attribute older-build evidence explicitly; do not call it current-head verification.
- **Device context:** platform, device model/OS when known, and the role of each device. For paired Rides checks, identify separate rider/driver actors backed by real database users in the same isolated test area, without publishing account identifiers or credentials.
- **Actions and results:** what was exercised, what was observed, and what remains untested or failed. A single-phone check is not paired coverage.
- **Visual evidence:** use a compact two- or three-column HTML table with `<img width="220">` portrait thumbnails, each linked to its full-resolution original. Caption each cell with the screen/role and source commit; keep build context and observed results above the grid. Do not stack full-width phone screenshots. Link a relevant Revyl report or preview when safe; a link alone does not replace the screenshots.
- **Cleanup:** record session revocation, active-trip cleanup, driver offline state, owned-device stop results, and private account-file deletion where applicable. Do not claim hardware release if it was not confirmed.

<!--
Replace IMAGE_URL with a public-safe uploaded screenshot URL and update each caption.
Add a third cell or further rows as needed. Keep each image's natural aspect ratio.

<table>
  <tr>
    <td align="center"><a href="IMAGE_URL"><img src="IMAGE_URL" width="220" alt="Screen and observed behavior"></a><br><sub><b>Screen / role</b> · source commit</sub></td>
    <td align="center"><a href="IMAGE_URL"><img src="IMAGE_URL" width="220" alt="Screen and observed behavior"></a><br><sub><b>Screen / role</b> · source commit</sub></td>
  </tr>
</table>

Never publish passwords, account emails, bearer/gate tokens, raw launch/session payloads, or signed artifact URLs.
-->
