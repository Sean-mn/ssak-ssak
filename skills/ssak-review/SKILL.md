---
name: ssak-review
description: Review one or more GitHub pull requests, focused on what each PR changes and what could hurt production, plus lint and team rules. Effort level sets how deep it goes. Two or more PRs are reviewed in parallel, one reviewer agent per PR, and reported together. Reports findings by severity to the user, or posts them as inline PR comments with --comment. Use for "/ssak-review high 42 --comment", "/ssak-review 42 43" or "review PR 42".
argument-hint: "[low|medium|high|xhigh] <pr#> [pr#...] [--comment] [--summary]"
# for: Opus 5.5 / Sonnet 5.5 as the main agent; not checked on Haiku
---

# ssak-review

Arguments: `$ARGUMENTS`

Paths below are relative to this skill's base directory (shown when the skill loads).
- `scripts/pr-worktree.sh <pr#>`: checks out the PR head in a detached worktree and prints `<head sha> <worktree path>`.
- `scripts/post-review.sh <pr#> <payload.json>`: posts one review, the only way this skill writes to GitHub. Refuses (exit 2) a non-`COMMENT` event, a `commit_id` that is not the PR head, or a head you already reviewed. Exit 3 means GitHub rejected the payload.
- `../ssak-clean-up/scripts/cleanup.sh remove review-<pr>...`: removes review worktrees.
- `references/review-template.md`: severity levels and the chat report shown to the user, plus the reviewer brief and multi-PR report for two or more PRs.
- `references/inline-template.md`: what gets posted to GitHub with `--comment`: the inline comment format and the review body.
- `../../agents/ssak-refuter.md`: refuter subagent instructions, used at `xhigh`.
- `../../agents/ssak-reviewer.md`: reviewer subagent instructions, used for two or more PRs.

## Subagents
- `ssak-refuter` (`ssak-ssak:ssak-refuter` when installed as a plugin) checks findings at `xhigh`.
- `ssak-reviewer` (`ssak-ssak:ssak-reviewer`) reviews one PR when two or more are given.
- If one is not registered, read its file above and pass its instructions with the brief to a general-purpose subagent.

## 0. Parse arguments
- Effort: `low`, `medium`, `high` or `xhigh`; `middle` means `medium`. Default `medium` when omitted.
- PR numbers: one or more positive integers, each with an optional leading `#` stripped (`#42` → `42`). At least one is required. Drop duplicates.
- `--comment`: post findings as inline PR comments. Without it, nothing is posted to GitHub.
- `--summary`: with `--comment`, also post the summary review body (verdict, severity counts, checks). Off by default. Without `--comment` it has no effect; say so in the report.
- Anything else, or no PR number: stop and show the usage `/ssak-review [low|medium|high|xhigh] <pr#> [pr#...] [--comment] [--summary]`.
- Check `gh auth status` passes and the current directory is a git repo of the PRs' repository. If not, say why and stop.
- With one PR, continue with steps 1 to 4. With two or more, go to "Two or more PRs" below; the effort and flags apply to every PR.

## 1. Gather
1. `gh pr view <pr> --json number,title,body,author,baseRefName,headRefName,headRefOid,files,additions,deletions,url` for the PR's intent and scope.
2. `gh pr diff <pr>` is the review scope. Findings must point at code this PR adds or changes, or at existing code the change now breaks.
3. `bash <skill dir>/scripts/pr-worktree.sh <pr>` to get the PR head on disk for reading context and running lint. Do all reads and commands for the PR inside that worktree, never in the main checkout. Install dependencies from the lockfile if lint or tests need them.
4. Team rules: read whichever exist in the worktree: `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `CONTRIBUTING.md`, `.github/PULL_REQUEST_TEMPLATE*`, `.editorconfig`, lint and formatter configs. A rule violation is a finding only if a rule file actually states it; cite the file.

## 2. Review by effort

| Effort | Context read | Commands run | Severities reported |
|---|---|---|---|
| low | The diff only | Lint on changed files | Critical, High |
| medium | Diff plus the full changed functions and their direct callers | Lint, type check or build | Critical, High, Medium |
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
Before delivering, check the report: every finding has `path:line`, a failure scenario and a severity from `references/review-template.md`; with `--comment`, every comment follows `references/inline-template.md`, tone included. Fix what does not match and check again; deliver only when all pass.
If something looks wrong but no rule file or template covers it, do not report it as a rule violation. At the end, propose one new rule (which file and its wording) and add it only after the user approves.

### Without `--comment`
Report to the user in chat using the "Chat report" format in `references/review-template.md`, in the user's language. Post nothing to GitHub.

### With `--comment`
1. Build one review from `references/inline-template.md`: an "Inline comment" per finding. A comment can only sit on a line in the PR diff; use `side: "RIGHT"` and the new file's line number.
2. The review body follows "Review body" in the template:
   - With `--summary`: the full summary.
   - Without it: empty, except findings that cannot be placed on a diff line, which always go in the body.
3. Write the payload to a temp file and post it as a single review:
   ```
   bash <skill dir>/scripts/post-review.sh <pr> <payload.json>
   ```
   Payload: `{"commit_id": "<head sha>", "event": "COMMENT", "body": "<body or empty>", "comments": [{"path": "...", "line": 12, "side": "RIGHT", "body": "..."}]}`. Leave `body` out when it is empty. It prints the review URL. On exit 2, tell the user why it refused and post nothing.
4. If GitHub rejects the payload (exit 3, message on stderr):
   - Some comment positions are invalid: move those comments into the body and run it again.
   - A body is required: run it again with the one-line body from the template.
5. If there are no findings: with `--summary`, post the summary alone; without it, post nothing. Tell the user either way.
6. Tell the user in chat what was posted: the review URL, the count per severity, and the same "Chat report".

## Two or more PRs: one reviewer per PR, then report together
1. Run `bash <skill dir>/scripts/pr-worktree.sh <pr>` for each PR, one at a time: concurrent runs share `FETCH_HEAD` and can check out another PR's head. Keep each `<head sha> <worktree path>`.
   - Pick each reviewer's model. `sonnet` at `low` or `medium` when `gh pr view <pr> --json files` shows no auth, payment, migration, deploy or infra, or secret-handling files. Otherwise no model, so the reviewer runs on the session model. Never pass a model stronger than the session's. Skip this when the subagent tool has no model option.
2. Launch one `ssak-reviewer` per PR on its model, all in parallel, with the "Reviewer brief" from `references/review-template.md`. The worktrees already exist, so do not use the subagent tool's workspace isolation option. Handle each PR independently: a reviewer that fails or returns no report ends that PR as not reviewed, with the reason.
3. At `xhigh`, as soon as a reviewer returns, launch one fresh `ssak-refuter` per Critical or High finding in its report, in parallel, with only the finding (file:line, claim, failure scenario) and that PR's worktree path. Do not wait for the other reviewers. Drop each `DISPROVED` finding from its PR's chat report, inline comments, counts and verdict. Reviewers cannot launch subagents, so the main agent does this.
4. Remove all review worktrees in one call, as in step 3: `bash <skill dir>/../ssak-clean-up/scripts/cleanup.sh remove review-<pr>...`. Fill in each chat report's Worktree line from its output.
5. Deliver:
   - Without `--comment`: the "Multi-PR report" from `references/review-template.md`, then each PR's chat report.
   - With `--comment`: post one review per PR as in step 4 "With `--comment`", from that PR's inline comments (`"on_diff": false` goes in the body) and head sha. Then the "Multi-PR report" with each review URL, then each PR's chat report.

## Rules
- Always `"event": "COMMENT"`. Never approve or request changes, never edit, merge or close the PR, never push to its branch.
- Write GitHub comments in the language of the PR description, in the tone `references/inline-template.md` sets.
- Remove the review worktree only through `cleanup.sh` as in step 3, never with `--force`.
- With two or more PRs, only the main agent posts to GitHub and removes worktrees.
