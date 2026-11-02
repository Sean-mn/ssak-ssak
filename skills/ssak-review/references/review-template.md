# ssak-review templates

Replace `<...>` with real values. Omit a severity section when it has no findings.

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

## Inline comment
One comment per finding, on the line the finding points at:
```
**<emoji> <Severity>: <short title>**

<Problem and production impact, 1-3 sentences.>

**Suggested fix:** <concrete change>
```
For a fix that fits in a few lines, add a GitHub suggestion block:
````
```suggestion
<replacement lines>
```
````

Review body (summary posted with the inline comments):
```
## ssak-review (effort: <level>)
<Verdict line>

| 🔴 Critical | 🟠 High | 🟡 Medium | ⚪ Low |
|---|---|---|---|
| <n> | <n> | <n> | <n> |

<Findings that could not be placed on a diff line, in the inline comment format with `path:line` added.>

<Checks section from the chat report.>
```
