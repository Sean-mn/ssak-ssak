# ssak-review chat report template

The report shown to the user in chat. Replace `<...>` with real values. Omit a severity section when it has no findings. What gets posted to GitHub with `--comment` is in `inline-template.md`.

## Severity
- 🔴 **Critical**: will break production or lose or expose data if merged. Must fix before merge.
- 🟠 **High**: likely bug, security weakness, or breaking change under realistic conditions. Should fix before merge.
- 🟡 **Medium**: edge case bug, missing error handling, lint error, or team rule violation. Fix in this PR if cheap.
- ⚪ **Low**: minor issue or suggestion with a concrete benefit. Optional.

## Chat report
```
## PR #<num> review: <title>
<url> · effort: <level, or "high (raised from medium: <signal>)"> · base: <base> · head: <short sha>

**Verdict**: <one line: e.g. "2 issues must be fixed before merge" / "No blocking issues">

| Severity | Count |
|---|---|
| 🔴 Critical | <n> |
| 🟠 High | <n> |
| 🟡 Medium | <n> |
| ⚪ Low | <n> |

### 🔴 Critical
1. **<short title>** — `<path>:<line>`
   - Problem: <what is wrong>
   - Impact: <what happens in production, under which input or condition>
   - Fix: <concrete change>

### 🟠 High
...

### 🟡 Medium
...

### ⚪ Low
...

### Checks
- Lint: <command> → <pass / n errors on changed lines, or "skipped: <reason>">
- Build / type check: <command> → <result, "not run at this effort", or "skipped: <reason>">
- Tests: <command> → <result, "not run at this effort", or "skipped: <reason>">
- Team rules checked: <files read, or "none found">
- Pre-existing: <lint errors on lines the PR did not change, or "none">

### Worktree
<removed, or kept: reason. Remove it later with /ssak-clean-up review-<num>>
```

## Reviewer brief (ssak-reviewer, two or more PRs)
```
Review PR #<num> at effort <level, or "high (raised from medium: <signal>)">.
- worktree: <worktree path> at head <head sha>  (already checked out; do all reads and commands inside it)
- skill dir: <ssak-review skill dir>
- report language: <the user's language>
- inline comments: <yes / no>
Answer in your defined report format.
```

## Multi-PR report
Shown first when two or more PRs were reviewed, followed by each PR's "Chat report" in PR number order. Leave out the Posted column without `--comment`.
```
## ssak-review: <n> PRs · effort: <level, or "auto" when none was given>

| PR | Effort | Model | Verdict | 🔴 | 🟠 | 🟡 | ⚪ | Posted |
|---|---|---|---|---|---|---|---|---|
| #<num> <title> | <level, "high (raised: <signal>)" when raised> | <reviewer model, e.g. sonnet, opus> | <one line> | <n> | <n> | <n> | <n> | <review URL / nothing to post> |

<Not reviewed: #<num>: <reason>. Omit when every PR was reviewed.>
```
