# Releasing

Feature PRs never touch the version, so they never conflict on it. A release is its own
PR.

1. From an up-to-date `main`, branch `chore/release-X.Y.Z`.
2. Bump `version` in `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json` and
   `.antigravity-plugin/plugin.json` to the same `X.Y.Z` (check.py fails on a mismatch). Change nothing else.
   So far every release has bumped the minor version (`0.10.0` → `0.11.0`); use a
   patch bump for a fixes-only release.
3. Preview the notes: `bash .github/release-notes.sh vX.Y.Z`. They list commits since
   the previous `v*` tag, grouped into Features (`feat`), Fixes (`fix`) and Other.
4. Open the PR titled `release vX.Y.Z: <highlights>`, all lowercase, e.g.
   `release v0.11.0: ssak-herdr, scout agent for issue grouping`. `pr-title.sh`
   rejects a title whose version does not match the manifests, or a release PR that
   does not bump it.
5. Squash merge. `release.yml` sees a version on `main` that has no release yet, tags
   `vX.Y.Z` and publishes a GitHub release with the notes.

Users update with `/plugin marketplace update ssak-ssak` in Claude Code, `codex plugin marketplace upgrade` in Codex, or
`git pull` and `agy plugin install .` in Antigravity. The release notes say so.
