---
name: ssak-issue
description: Work on GitHub issues by number. One issue is handled directly by the main agent; two or more run in parallel, each in its own git worktree with a worker agent, then a verifier agent checks the result and the main agent reports. Use for "/ssak-issue 12 15" or "work on issues 12 and 15".
argument-hint: <issue-num> [issue-num...]
---

# ssak-issue

Arguments: `$ARGUMENTS`

Paths below are relative to this skill's base directory (shown when the skill loads).
- `agents/ssak-worker.md`: worker subagent instructions.
- `agents/ssak-verifier.md`: verifier subagent instructions.
- `scripts/base-branch.sh`: prints the ref to branch from. A develop-like branch if one exists, otherwise the default branch (main).
- `scripts/make-worktrees.sh <num...>`: creates a `ssak/issue-<num>` branch and worktree per issue.
- `references/templates.md`: agent briefs and the final report format.

## Subagents
`agents/ssak-worker.md` and `agents/ssak-verifier.md` define the two subagents used when working on multiple issues:
- If `ssak-worker` / `ssak-verifier` (or `ssak-ssak:ssak-worker` / `ssak-ssak:ssak-verifier`) are already registered in the harness, invoke them by name.
- Otherwise, read `agents/ssak-worker.md` and `agents/ssak-verifier.md` and either register them dynamically (e.g., `define_subagent`) or pass their instructions along with the brief to a general-purpose subagent.

## 0. Prepare
1. Check that every argument is a positive integer. If not, stop and show the usage (`/ssak-issue <issue-num> [issue-num...]`). Drop duplicate numbers.
2. Check that the current directory is a git repo and `gh auth status` passes. If not, say why and stop.

## One issue: the main agent works directly
1. Read it with `gh issue view <num> --comments`.
2. If `git status --porcelain` is not empty, ask the user what to do before switching branches.
3. `base=$(bash <skill dir>/scripts/base-branch.sh)`, then `git switch --no-track -c ssak/issue-<num> "$base"`. If the branch already exists, `git switch ssak/issue-<num>` instead.
4. Implement as usual and run the project's tests, build and lint.
5. Commit as `<type>: <summary> (#<num>)`.
6. Report using the final report format in `references/templates.md`.

## Two or more issues: work, verify, report
1. Run `bash <skill dir>/scripts/make-worktrees.sh <num...>`. The first output line is `base <ref>`, followed by one `issue <num> <branch> <worktree path>` line per issue.
2. Launch one `ssak-worker` subagent (`agents/ssak-worker.md`) per issue, all in parallel. Use the "Worker brief" from `references/templates.md`. The script already created the worktrees, so do not use the subagent tool's workspace isolation option.
3. Handle each issue independently; never wait on another issue.
   - If the worker reports `BLOCKED`, that issue ends there without verification.
   - If the worker reports `DONE`, launch `ssak-verifier` (`agents/ssak-verifier.md`) with the "Verifier brief".
4. If verification returns `FAIL`, request a rework.
   - Send the "Rework request" to the same worker with a message tool (`SendMessage` / `send_message`). If unavailable, start a new worker and include the previous worker's report.
   - After the rework, verify again with a fresh verifier so it is not anchored on the earlier verdict.
   - At most 2 reworks per issue. If the third verification still fails, the issue ends as FAIL.
5. When every issue is finished:
   1. Compare changed files across the issue branches with `git diff --name-only <base>...<branch>` to find overlaps.
   2. Report using the "Final report" format in `references/templates.md`.

## Rules
- Do not push, open PRs, close issues, or comment on issues. The user decides after reading the report.
- The main agent relays the verifier's verdict as is and does not edit issue branches itself.
- Do not delete worktrees. Only print the cleanup command in the report.
