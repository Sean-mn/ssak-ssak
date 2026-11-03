# ssak-issue templates

Replace `<...>` with real values.

## Worker brief (ssak-worker)
```
Work on issue #<num>.
- worktree: <worktree path>  (do all work inside it)
- branch: <branch>  (base: <base>)
- read the issue: gh issue view <num> --comments
Implement it, commit, then answer in your defined report format.
```

## Coupled worker brief (ssak-worker)
```
Work on coupled issues #<num>, #<num>... in this order. <why they are coupled, one line>
- #<num>: worktree <worktree path>, branch <branch>, base <base>
- #<num>: worktree <worktree path>, branch <branch>, base <base or "stacked on <earlier branch>">
For a stacked issue, first run git -C "<its worktree>" merge --ff-only <earlier branch> after the earlier issue is committed.
Do each issue only in its own worktree, commit it there, then answer with one report per issue in your defined format.
```

## Verifier brief (ssak-verifier)
```
Verify issue #<num>.
- worktree: <worktree path>
- branch: <branch>, base: <base>
- changes: git -C "<worktree path>" diff <base>...HEAD
- worker report (for reference only, do not trust it as is):
<full worker report>
```

## Rework request (to ssak-worker)
```
Verification FAILED (rework <k>/2). Fix the FAIL reasons in the verifier report below, commit as a new commit, and report again in the same format.
<full verifier report>
```

## Final report (main agent to user)
```
## ssak-issue result (base: <base>)

| Issue | Result | Branch | Reworks | Summary |
|---|---|---|---|---|
| #<num> | ✅ PASS / ❌ FAIL / ⛔ BLOCKED | <branch> | <0-2> | <one line> |

### Needs attention
- #<num>: <FAIL reason, BLOCKED reason, verifier NOTE, "suspected pre-existing failure" items>
- Overlapping files: <files changed by more than one issue branch; may conflict on merge. "none" if none>
- Stacked: <#<num> on #<num>: merge the earlier one first, or open its PR with --base <earlier branch>. "none" if none>

### Next steps
- push and PR: git push -u origin <branch> && gh pr create --base <base branch name> --head <branch> --fill
- worktrees: <removed, branches kept / kept: <ids and why>>
- delete the branches once pushed or merged: /ssak-clean-up for `ssak/*` branches, `git branch -d <branch>` for others
```
