# ssak-contrib templates

Replace `<...>` with real values. Write messages to the user in the user's language; write PR text in the language the repo uses.

## Pre-flight summary (to the user, before forking)
```
## Contribute to <owner/repo>#<issue#>: <issue title>
<issue url>

**Issue status**: ✅ free / ⚠️ needs your call / ⛔ taken — <one line with evidence>

| Rule | Found | Source |
|---|---|---|
| AI policy | <banned / disclosure required: how / not found> | <file:line> |
| Claiming | <...> | <...> |
| Target branch | <branch> | <...> |
| CLA / DCO | <...> | <...> |
| Commit / PR title format | <...> | <...> |
| Changelog | <...> | <...> |
| Dev commands | <test / lint / build commands> | <...> |

**You need to do**: <CLA signing, claiming comment, etc. "nothing" if none>
**Plan**: fork <me>/<name> (if not there), branch ssak/contrib-<issue#> from <base>, implement, verify, then show you the PR draft.
```
Then ask whether to proceed.

## Verifier brief (ssak-verifier)
```
Verify issue #<issue#> of <owner/repo>.
- worktree: <clone path>
- branch: <branch>, base: <base ref>
- changes: git -C "<clone path>" diff <base ref>...HEAD
- This is a contribution to someone else's repo. Besides your usual checks, mark FAIL for any violation of these rules:
<rules table from the pre-flight summary>
- Also FAIL on changes unrelated to the issue (formatting, refactors, dependency bumps) unless the issue asks for them.
- Worker report (for reference only):
<summary of what was changed and the tests run>
```

## PR body (only when the repo has no PR template)
```
<what the PR changes and why, 2-4 sentences>

Fixes #<issue#>

## Changes
- <change>

## Testing
- <command> → <result>

<AI disclosure in the form the repo requires, if any>
```

## PR draft (to the user, before pushing)
```
## PR draft for <owner/repo>#<issue#>
**Title**: <title>
**Base**: <owner/repo>:<base>  ←  **Head**: <me>:<branch>  (opened as a draft)

<body>

**Commits**: <hash subject>, one per line
**Verification**: <PASS after k reworks / FAIL: reasons>
```
Then ask whether to push to the fork and open the draft PR.

## Final report
```
## ssak-contrib result: <owner/repo>#<issue#>
- PR: <draft PR url, or "not opened">
- Branch: <me>:<branch> (clone: <path>)
- Verification: <PASS / FAIL, reworks k>
- You still need to: <sign CLA, mark the PR ready for review when satisfied, etc.>
```
