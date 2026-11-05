# ssak-issue templates

Replace `<...>` with real values.

## Scout brief (ssak-scout)
```
Map issue #<num> to the code it would change.
- worktree: <worktree path>  (at base <base>; read only)
- read the issue: gh issue view <num> --comments
Answer in your defined report format.
```

## Worker brief (ssak-worker)
```
Work on issue #<num>.
- worktree: <worktree path>  (do all work inside it)
- branch: <branch>  (base: <base>)
- commit format: <the repo's commit format, e.g. fix(api): <summary> (#<num>)>
- read the issue: gh issue view <num> --comments
- scout map (a starting point, check it yourself; omit the line if there is none):
<full scout report>
Implement it, commit, then answer in your defined report format.
```

## Coupled worker brief (ssak-worker)
```
Work on coupled issues #<num>, #<num>... in this order. <why they are coupled, one line>
- #<num>: worktree <worktree path>, branch <branch>, base <base>
- #<num>: worktree <worktree path>, branch <branch>, base <base or "stacked on <earlier branch>">
Commit format: <the repo's commit format, e.g. fix(api): <summary> (#<num>)>
Scout maps (a starting point, check them yourself; omit for issues without one):
<full scout report per issue>
For a stacked issue, first run git -C "<its worktree>" merge --ff-only <earlier branch> after the earlier issue is committed.
Do each issue only in its own worktree, commit it there, then answer with one report per issue in your defined format.
```

## Herdr worker brief (file read by a Claude Code pane)
```
You are the ssak-worker. Read <absolute path of ../../agents/ssak-worker.md> and follow it as your instructions.
<the Worker brief or Coupled worker brief above, filled in>
When done, write your report in that file's report format to <main repo>/.claude/worktrees/ssak-issue-<num>.report.md (one file per issue for a coupled group), then reply only "REPORTED". Write nothing else outside your worktree.
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

| Issue | Result | Branch | Model | Reworks | Summary |
|---|---|---|---|---|---|
| #<num> | ✅ PASS / ❌ FAIL / ⛔ BLOCKED | <branch> | <the model that did the work, e.g. sonnet, opus; "sonnet → opus" when a rework moved it up> | <0-2> | <one line> |

### Needs attention
- #<num>: <FAIL reason, BLOCKED reason, verifier NOTE, "suspected pre-existing failure" items>
- Overlapping files: <files changed by more than one issue branch; may conflict on merge. "none" if none>
- Stacked: <#<num> on #<num>: merge the earlier one first, or open its PR with --base <earlier branch>. "none" if none>

### Next steps
- push and PR: git push -u origin <branch> && gh pr create --base <base branch name> --head <branch> --fill
- worktrees: <removed, branches kept / kept: <ids and why>>
- delete the branches once pushed or merged: /ssak-clean-up for `ssak/*` branches, `git branch -d <branch>` for others
```
