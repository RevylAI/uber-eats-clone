# Feature pull request evidence

When developing or verifying a feature against a Revyl device, include the device context and visual evidence in the feature PR description, not only in comments or a final chat message. Follow `.github/pull_request_template.md`.

- Identify the source commit, app/profile, exact build/version, device platform/model/OS when known, and each device's actor role.
- Embed public-safe screenshots or recordings with captions explaining the screen, action, observed result, and source build. Include relevant safe report/preview links where available.
- Format portrait screenshots as a compact HTML table like Revyl's proof grids: two or three columns, `<img width="220">` thumbnails, centered cells, and short captions naming the screen/role and source commit. Link each thumbnail to its full-resolution original. Do not stack unrestricted full-width phone screenshots.
- Distinguish manual device observations, automatic Proof of Changes, compilation, and executed tests. Explicitly attribute earlier-build evidence and report failures, untested paths, and blockers without claiming current-head coverage.
- Paired Rides behavior requires separate real database rider/driver users in the same isolated test service area, native actions on both phones, and evidence from both actors. Backend reads may corroborate state; backend mutations must not stand in for native lifecycle actions.
- Report applicable cleanup truthfully: complete/cancel active trips, sign out/revoke sessions, take the driver offline, stop only owned devices, and remove private account files. A completed session report is not proof of hardware release.
- Never publish account emails, passwords, session/gate tokens, raw launch payloads, or signed download URLs. Keep private evidence outside Git and sanitize media before publishing.

If no Revyl device was used, state that explicitly rather than implying device validation. Preserve the independent Eats and Rides Revyl Benchmarks projects; artifact publication to another account does not authorize migrating the GitHub integration.
