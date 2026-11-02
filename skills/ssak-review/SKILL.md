---
name: ssak-review
description: Review a GitHub pull request, focused on what the PR changes and what could hurt production, plus lint and team rules. Effort level sets how deep it goes. Reports findings by severity to the user, or posts them as inline PR comments with --comment. Use for "/ssak-review high 42 --comment" or "review PR 42".
argument-hint: [low|middle|high|xhigh] <pr-num> [--comment]
---

# ssak-review

Arguments: `$ARGUMENTS`

Paths below are relative to this skill's base directory (shown when the skill loads).
- `scripts/pr-worktree.sh <pr-num>`: checks out the PR head in a detached worktree and prints `<head sha> <worktree path>`.
- `references/review-template.md`: the severity-ordered report and the inline comment format.

## 0. Parse arguments
- Effort: `low`, `middle`, `high` or `xhigh`. Default `middle` when omitted.
- PR number: a positive integer. Required.
- `--comment`: post findings as inline PR comments. Without it, nothing is posted to GitHub.
- Anything else, or a missing PR number: stop and show the usage `/ssak-review [low|middle|high|xhigh] <pr-num> [--comment]`.
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

For `high` and `xhigh`, re-read the code behind every finding before reporting it and drop any you cannot back with a concrete scenario. For `xhigh`, give each Critical or High finding to a fresh subagent with only the finding and the worktree path and ask it to disprove the finding; drop the finding if it can.

Do not report: style preferences no rule file states, problems in code the PR did not touch and does not affect, or speculation without a failure scenario. Lint errors on lines the PR did not change go under "Pre-existing" in the report, not as findings.

## 3. Deliver
### Without `--comment`
Report to the user in chat using the "Chat report" format in `references/review-template.md`, in the user's language. Post nothing to GitHub.

### With `--comment`
1. Build one review with the "Inline comment" format from the template. A comment can only sit on a line in the PR diff; use `side: "RIGHT"` and the new file's line number. Findings that cannot be placed on a diff line go into the review body.
2. Write the payload to a temp file and post it as a single review:
   ```
   gh api repos/{owner}/{repo}/pulls/<pr>/reviews -X POST --input <payload.json>
   ```
   Payload: `{"commit_id": "<head sha>", "event": "COMMENT", "body": "<summary>", "comments": [{"path": "...", "line": 12, "side": "RIGHT", "body": "..."}]}`
3. If the API rejects some comment positions (422), move those comments into the body and post again. Never post twice successfully.
4. If there are no findings, post nothing and tell the user.
5. Tell the user in chat what was posted: the review URL, the count per severity, and the same "Chat report".

## Rules
- Always `"event": "COMMENT"`. Never approve or request changes, never edit, merge or close the PR, never push to its branch.
- Write GitHub comments in the language of the PR description.
- Leave the review worktree in place; the report ends with its cleanup command.
