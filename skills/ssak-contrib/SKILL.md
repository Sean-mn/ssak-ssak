---
name: ssak-contrib
description: Contribute to someone else's open source repo by issue. Reads the repo's contribution rules (including any AI policy), checks nobody else has the issue, forks and branches, implements, verifies against the repo's rules, then opens a draft PR after the user approves. With --find, lists beginner-friendly issues nobody has taken. Use for "/ssak-contrib owner/repo 123", "/ssak-contrib owner/repo --find" or "contribute to owner/repo issue 123".
argument-hint: "<owner/repo> <issue#> | <owner/repo> --find"
# for: Opus 5.5 / Sonnet 5.5 as the main agent; not checked on Haiku
---

# ssak-contrib

Arguments: `$ARGUMENTS`

Paths below are relative to this skill's base directory (shown when the skill loads).
- `scripts/guidelines.sh <owner/repo>`: prints the repo's contribution rule files from GitHub, without cloning.
- `scripts/issue-status.sh <owner/repo> <issue#>`: prints state, assignees, labels, linked PRs (closing keyword, Development sidebar link, mentions), PRs linked in comments, claim-like comments and the last 10 comments.
- `../ssak-issue/scripts/find-issues.sh <owner/repo> --beginner`: lists open beginner-labeled issues grouped as FREE, CLAIMED, NOT READY and TAKEN. Both scripts source `../ssak-issue/scripts/common.sh`.
- `scripts/setup-fork.sh <owner/repo> <issue#> [base-branch]`: forks if needed, clones or reuses a clone, and creates `ssak/contrib-<issue#>`. Prints `fork`, `push-remote`, `base`, `path`, `branch` lines. Exit 3 means the clone has uncommitted changes.
- `scripts/open-pr.sh <path> <push-remote> <branch> <owner/repo> <base-branch> <title> <body-file>`: pushes the branch to the fork and opens a draft PR, the only way this skill pushes or opens PRs. Refuses (exit 2) to push to upstream, never force-pushes, prints the PR URL.
- `references/rules-checklist.md`: which rules to extract and when to stop.
- `references/templates.md`: pre-flight summary, verifier brief, PR body, PR draft and final report.

## Subagent
Verification uses the `ssak-verifier` subagent (`ssak-ssak:ssak-verifier` when installed as a plugin). If it is not registered, read `../../agents/ssak-verifier.md` and pass its instructions with the brief to a general-purpose subagent.

## Checklist
Copy this into your reply and tick it as you go:
```
- [ ] 1. Rules and issue status; stop if AI is banned or the issue is taken
- [ ] 2. Pre-flight summary; wait for yes
- [ ] 3. setup-fork.sh
- [ ] 4. Implement with the repo's own commands
- [ ] 5. Verify; on FAIL fix and back to 5, at most 2 reworks
- [ ] 6. PR draft; wait for yes; open-pr.sh
- [ ] 7. Final report
```

## 0. Parse arguments
- Accept `owner/repo 123`, `owner/repo #123`, an issue URL `https://github.com/owner/repo/issues/123`, or `owner/repo --find`.
- Anything else: stop and show the usage `/ssak-contrib <owner/repo> <issue#> | <owner/repo> --find`.
- Check `gh auth status` passes. If not, say why and stop.

## Find issues (`--find`)
1. Run `bash <skill dir>/../ssak-issue/scripts/find-issues.sh <owner/repo> --beginner`.
2. If the repo has no beginner labels or nothing is FREE, say so and offer to search all open issues by running it without `--beginner`.
3. Show the FREE issues, then CLAIMED with the claim line. Summarize NOT READY and TAKEN in one line each.
4. Ask the user to pick one issue, then continue at step 1 with it. The full check in step 1 still runs, because find does not read PR links pasted in comments.

## 1. Rules and issue status (read only)
1. Run `guidelines.sh <owner/repo>` and `issue-status.sh <owner/repo> <issue#>`. Read the issue body with `gh issue view <issue#> -R <owner/repo>`.
2. Fill the rules table and check the stop conditions from `references/rules-checklist.md`.
3. If the AI policy bans AI-generated contributions, or a stop condition holds, report why with the evidence and stop. Do not fork.

## 2. Pre-flight confirmation
Show the "Pre-flight summary" from `references/templates.md` and ask the user whether to proceed. Forking creates a public repo on the user's account, so do not continue without a yes. If the user must do something first (sign a CLA, comment to claim the issue), say so; never do it for them.

## 3. Set up the fork and branch
Run `setup-fork.sh <owner/repo> <issue#> [base-branch]`, passing the target branch when the rules name one. On exit 3, ask the user how to handle the uncommitted changes in that clone. Do all later work inside the printed `path`.

## 4. Implement
- Install dependencies and run the commands the rules give, not guessed ones.
- Change only what the issue needs. No drive-by refactors, reformatting or dependency bumps.
- Add tests, docs and changelog or changeset entries the rules ask for.
- Commit in the repo's commit format. Use `git commit -s` when DCO is required. Add the AI disclosure in commits only if the policy asks for it there.

## 5. Verify
1. Launch `ssak-verifier` with the "Verifier brief" from `references/templates.md`.
2. On FAIL, fix the reasons yourself with new commits (no amend) and verify again with a fresh verifier.
3. At most 2 reworks. If the third verification still fails, skip the PR and go to the final report with the FAIL reasons.

## 6. PR draft and confirmation
1. Fill the repo's PR template if it has one; otherwise use the "PR body" template. Include `Fixes #<issue#>` and any required AI disclosure. Follow the PR title format.
2. Show the "PR draft" from `references/templates.md` and ask whether to push and open it. If the user wants changes: wording → back to 6.1; code → back to 4, then 5.
3. On yes, write the body to a temp file and run:
   ```
   bash <skill dir>/scripts/open-pr.sh <path> <push-remote> <branch> <owner/repo> <base branch> "<title>" <body file>
   ```
   `<base branch>` is the `base` line from `setup-fork.sh` without the remote (`upstream/main` → `main`). On exit 2, tell the user why it refused and stop.
4. Finish with the "Final report". If a verifier FAIL reason was not covered by the brief, the repo's rules or `references/rules-checklist.md`, propose one new rule for it at the end and add it only after the user approves.

## Rules
- When an issue allows more than one reading or a choice is the user's (which issue, scope, design), ask the user as in `../../references/asking-the-user.md`: with options and a recommended one first, and decide alone only if the user said to go with your recommendation.
- Nothing visible on GitHub happens before the user's yes in step 2 (fork) and step 6 (push and PR).
- Always open the PR as a draft. Never mark it ready, request reviewers, or comment on the issue or PR.
- Never push to upstream, never force-push, never sign a CLA or claim an issue for the user.
