# Repository agent rules

These rules apply to every AI or automated coding agent working in this
repository. The current product scope is **Linux amd64 only**.

## Publish completed work

1. Do not leave a completed, validated change only in a local checkout.
2. Before reporting a change as complete, run the relevant checks, commit it,
   and push it to GitHub.
3. If direct pushes to `main` are protected, create or update a focused pull
   request immediately. Report its URL and live check state.
4. Do not force-push, disable branch protection, or claim a merge completed
   when required checks are pending, cancelled, or failed.
5. Once all required checks pass and the change is in scope, merge through the
   protected GitHub workflow or ask the repository owner for a decision if
   approval is required.

## Version and release evidence

1. Treat the `version:` value in `pubspec.yaml` as the source version.
2. Any version change must update the matching
   `docs/releases/<major>.<minor>.<patch>.md` record with the exact source
   version, including its build suffix.
3. The evidence table must state the version and mark every required control
   as `PASS`, `IN PROGRESS`, `NOT CONFIRMED`, `NOT TESTED`, or `NOT AVAILABLE`.
   Never turn an incomplete result into `PASS`.
4. Only call a release confirmed after the tagged source, `.deb`, checksum,
   detached signature, SBOM, automated checks, and clean-install evidence
   identify the same version and commit.
5. Never claim that a test suite, security score, AI review, or signature
   guarantees real-money safety.

## Release publication

For a Linux release, publish the signed tag, `.deb`, detached signature,
`SHA256SUMS`, SBOM, and the matching versioned evidence record in the same
GitHub Release. Keep the latest stable release and prereleases accurately
labelled; a prerelease is not a confirmed stable release merely because it is
newer.
