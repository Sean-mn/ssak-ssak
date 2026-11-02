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
<url> · effort: <level> · base: <base> · head: <short sha>

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
- Lint: <command> → <pass / n errors on changed lines>
- Build / type check: <command> → <result, or "not run at this effort">
- Tests: <command> → <result, or "not run at this effort">
- Team rules checked: <files read, or "none found">
- Pre-existing: <lint errors on lines the PR did not change, or "none">

### Worktree
<removed, or kept: reason. Remove it later with /ssak-clean-up review-<num>>
```
