---
name: ssak-review
description: Review a GitHub pull request, focused on what the PR changes and what could hurt production, plus lint and team rules. Effort level sets how deep it goes. Reports findings by severity to the user, or posts them as inline PR comments with --comment. Use for "/ssak-review high 42 --comment" or "review PR 42".
argument-hint: "[low|middle|high|xhigh] <pr#> [--comment] [--summary]"
---

# ssak-review

Arguments: `$ARGUMENTS`

Paths below are relative to this skill's base directory (shown when the skill loads).
- `scripts/pr-worktree.sh <pr#>`: checks out the PR head in a detached worktree and prints `<head sha> <worktree path>`.
- `references/review-template.md`: severity levels and the chat report shown to the user.
- `references/inline-template.md`: what gets posted to GitHub with `--comment`: the inline comment format and the review body.
- `../../agents/ssak-refuter.md`: refuter subagent instructions, used at `xhigh`.

## Subagent
At `xhigh`, findings are checked by the `ssak-refuter` subagent (`ssak-ssak:ssak-refuter` when installed as a plugin). If it is not registered, read `../../agents/ssak-refuter.md` and pass its instructions with the brief to a general-purpose subagent.

## 0. Parse arguments
- Effort: `low`, `middle`, `high` or `xhigh`. Default `middle` when omitted.
- PR number: a positive integer, with an optional leading `#` stripped (`#42` → `42`). Required.
- `--comment`: post findings as inline PR comments. Without it, nothing is posted to GitHub.
- `--summary`: with `--comment`, also post the summary review body (verdict, severity counts, checks). Off by default. Without `--comment` it has no effect; say so in the report.
- Anything else, or a missing PR number: stop and show the usage `/ssak-review [low|middle|high|xhigh] <pr#> [--comment] [--summary]`.
- Check `gh auth status` passes and the current directory is a git repo of the PR's repository. If not, say why and stop.

## 1. Gather
1. `gh pr view <pr> --json number,title,body,author,baseRefName,headRefName,headRefOid,files,additions,deletions,url` for the PR's intent and scope.
2. `gh pr diff <pr>` is the review scope. Findings must point at code this PR adds or changes, or at existing code the change now breaks.
3. `bash <skill dir>/scripts/pr-worktree.sh <pr>` to get the PR head on disk for reading context and running lint. Do all reads and commands for the PR inside that worktree, never in the main checkout. Install dependencies from the lockfile if lint or tests need them.
4. Team rules: read whichever exist in the worktree: `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `CONTRIBUTING.md`, `.github/PULL_REQUEST_TEMPLATE*`, `.editorconfig`, lint and formatter configs. A rule violation is a finding only if a rule file actually states it; cite the file.

## 2. Review by effort

| Effort | Context read | Commands run | Severities reported |
|---|---|---|---|
| low | The diff only | Lint on changed files | Critical, High |
| middle | Diff plus the full changed functions and their direct callers | Lint, type check or build | Critical, High, Medium |
| high | Also config, migrations, call sites across the repo, and related tests | Also the tests related to the change | All, including Low |
| xhigh | Same as high | Also the full test suite | All, and each Critical or High finding is checked by an independent subagent |

At every level, look in this order:
1. **Production impact**: data loss or corruption, security (injection, auth bypass, secret exposure), outages and crashes, missing error handling on external calls, breaking changes to APIs, schemas, migrations, env vars or config, performance regressions on hot paths, concurrency and race conditions, irreversible operations without a guard.
2. **Correctness of the change**: does the code do what the PR says, edge cases, regressions in touched behavior.
3. **Lint and team rules**: lint errors on changed lines, violations of the rule files from step 1.4.

For `high` and `xhigh`, re-read the code behind every finding before reporting it and drop any you cannot back with a concrete scenario. For `xhigh`, launch one fresh `ssak-refuter` per Critical or High finding, in parallel, with only the finding (file:line, claim, failure scenario) and the worktree path; drop the finding if it returns `DISPROVED`.

Do not report: style preferences no rule file states, problems in code the PR did not touch and does not affect, or speculation without a failure scenario. Lint errors on lines the PR did not change go under "Pre-existing" in the report, not as findings.

## 3. Clean up
The review is done with the code on disk, so remove the review worktree before delivering:
```
bash <skill dir>/../ssak-clean-up/scripts/cleanup.sh remove review-<pr>
```
Never pass `--force`. If it skips the worktree (e.g. uncommitted changes from installs or test runs), leave it and say why in the report's Worktree line.

## 4. Deliver
### Without `--comment`
Report to the user in chat using the "Chat report" format in `references/review-template.md`, in the user's language. Post nothing to GitHub.

### With `--comment`
1. Build one review from `references/inline-template.md`: an "Inline comment" per finding. A comment can only sit on a line in the PR diff; use `side: "RIGHT"` and the new file's line number.
2. The review body follows "Review body" in the template:
   - With `--summary`: the full summary.
   - Without it: empty, except findings that cannot be placed on a diff line, which always go in the body.
3. Write the payload to a temp file and post it as a single review:
   ```
   gh api repos/{owner}/{repo}/pulls/<pr>/reviews -X POST --input <payload.json>
   ```
   Payload: `{"commit_id": "<head sha>", "event": "COMMENT", "body": "<body or empty>", "comments": [{"path": "...", "line": 12, "side": "RIGHT", "body": "..."}]}`. Leave `body` out when it is empty.
4. If the API rejects the payload (422):
   - Some comment positions are invalid: move those comments into the body and post again.
   - A body is required: post again with the one-line body from the template.
   - Never post twice successfully.
5. If there are no findings: with `--summary`, post the summary alone; without it, post nothing. Tell the user either way.
6. Tell the user in chat what was posted: the review URL, the count per severity, and the same "Chat report".

## Rules
- Always `"event": "COMMENT"`. Never approve or request changes, never edit, merge or close the PR, never push to its branch.
- Write GitHub comments in the language of the PR description, in the tone `references/inline-template.md` sets.
- Remove the review worktree only through `cleanup.sh` as in step 3, never with `--force`.
