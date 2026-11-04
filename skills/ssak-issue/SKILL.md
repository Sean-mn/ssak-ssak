---
name: ssak-issue
description: Work on GitHub issues by number, each in its own git worktree on a branch named by the repo's convention. One issue is handled directly by the main agent; two or more run in parallel with a worker agent each. A verifier agent checks every issue, then the main agent reports. With --find, lists open issues nobody has taken yet and lets the user pick. Use for "/ssak-issue 12 15", "/ssak-issue --find" or "work on issues 12 and 15".
argument-hint: "<issue#> [issue#...] | --find"
---

# ssak-issue

Arguments: `$ARGUMENTS`

Paths below are relative to this skill's base directory (shown when the skill loads).
- `../../agents/ssak-worker.md`: worker subagent instructions.
- `../../agents/ssak-verifier.md`: verifier subagent instructions.
- `../../agents/ssak-scout.md`: scout subagent instructions.
- `scripts/base-branch.sh`: prints the ref to branch from. A develop-like branch that has commits the default branch lacks, otherwise the default branch (main).
- `scripts/make-worktrees.sh <num>[:<branch>]...`: creates a `.claude/worktrees/ssak-issue-<num>` worktree per issue on `<branch>` (default `ssak/issue-<num>`).
- `scripts/find-issues.sh <owner/repo> [--beginner]`: lists open issues grouped as FREE, CLAIMED, NOT READY and TAKEN. TAKEN means a linked PR (closing keyword or Development link) or another assignee.
- `scripts/common.sh`: shared helpers, sourced by the scripts above and by ssak-contrib.
- `references/templates.md`: agent briefs and the final report format.

## Subagents
`../../agents/ssak-worker.md`, `../../agents/ssak-verifier.md` and `../../agents/ssak-scout.md` define the three subagents: the worker and scout for two or more issues, the verifier for every issue:
- If `ssak-worker` / `ssak-verifier` / `ssak-scout` (or `ssak-ssak:ssak-worker` / `ssak-ssak:ssak-verifier` / `ssak-ssak:ssak-scout`) are already registered in the harness, invoke them by name.
- Otherwise, read the agent file and either register them dynamically (e.g., `define_subagent`) or pass their instructions along with the brief to a general-purpose subagent.

## 0. Prepare
1. Check that the current directory is a git repo and `gh auth status` passes. If not, say why and stop.
2. If the only argument is `--find`, go to "Find issues" below.
3. Otherwise strip a leading `#` from each argument (`#12` → `12`), then check that every argument is a positive integer. If not, stop and show the usage (`/ssak-issue <issue#> [issue#...] | --find`). Drop duplicate numbers.

## Find issues (`--find`)
1. Run `bash <skill dir>/scripts/find-issues.sh "$(gh repo view --json nameWithOwner -q .nameWithOwner)"`.
2. Show the user the FREE issues first (issues assigned to them are listed first), then CLAIMED with the claim line. Summarize NOT READY and TAKEN in one line each with their numbers.
3. Ask which issues to work on; several may be picked. Start nothing until the user picks.
4. Continue from "One issue" or "Two or more issues" below with the picked numbers. Before starting a CLAIMED, NOT READY or TAKEN issue, confirm the user still wants it.

## Branch names
Name each issue's branch by the repo's own convention:
1. Look for a branch naming rule in CONTRIBUTING.md (also under `.github/` and `docs/`), CLAUDE.md and AGENTS.md.
2. If there is none, infer the pattern from recent branches: `gh pr list --state all --limit 30 --json headRefName -q '.[].headRefName'` and `git branch -r`. Ignore bot branches (dependabot, renovate) and long-lived ones (main, develop, release).
3. Fill the pattern from the issue (`gh issue view <num> --json title,labels`): its number, a type in the repo's words (e.g. `fix` for a bug), and a short lowercase ASCII kebab-case summary of the title.
4. If no clear pattern shows up, use `ssak/issue-<num>`.

## Commit format
Commit by the repo's own format too: a rule in the files above or a commitlint config, otherwise the pattern of `git log --oneline -20 <base>` (type and scope, a trailing `(#<num>)` or not). If no clear pattern shows up, use `<type>: <summary> (#<num>)`.

## Worker model
Small work does not need the session's model. When grouping issues, pick each group's worker model from what you read:
- `sonnet`: docs, typos, copy, config, or a small fix in one or two files with clear acceptance criteria.
- No model, so the worker runs on the session model: everything else, e.g. a bug with an unclear cause, changes across several files, security, migrations or concurrency, and every coupled group.

Never pass a model stronger than the session's. Skip this when the subagent tool has no model option.

## One issue: the main agent works directly
1. Read it with `gh issue view <num> --comments`.
2. Pick the branch name (see "Branch names"), then run `bash <skill dir>/scripts/make-worktrees.sh <num>:<branch>`. The output is `base <ref>` and `issue <num> <branch> <worktree path>`. Only this script creates the worktree: never create one with a worktree tool given a `name` (e.g. `EnterWorktree`), which makes its own branch named after the worktree. To move the session into it, use such a tool only with the printed `path`.
3. Work only inside that worktree: run every command as `cd "<worktree path>" && ...` and edit files by absolute path under it. Do not touch the main checkout. A fresh worktree may lack dependencies; install them from the lockfile if needed.
4. Implement as usual and run the project's tests, build and lint.
5. Commit in the repo's format (see "Commit format").
6. Launch `ssak-verifier` (`../../agents/ssak-verifier.md`) with the "Verifier brief", giving your own summary and test results as the worker report. On `FAIL`, fix the reasons with new commits (no amend) and verify again with a fresh verifier. At most 2 reworks; if the third verification still fails, the issue ends as FAIL.
7. From the directory you ran `make-worktrees.sh` in (not the worktree), remove the worktree but keep the branch: `bash <skill dir>/../ssak-clean-up/scripts/cleanup.sh remove --keep-branch issue-<num>`. Never pass `--force`; if it skips the worktree (uncommitted changes), it stays and goes in the report.
8. Report using the final report format in `references/templates.md`.

## Two or more issues: work, verify, report
1. Read every issue with `gh issue view <num> --comments`, pick each branch name (see "Branch names"), then run `bash <skill dir>/scripts/make-worktrees.sh <num>:<branch>...`. The first output line is `base <ref>`, followed by one `issue <num> <branch> <worktree path>` line per issue.
2. For each issue whose text does not already name the files or functions it changes, launch an `ssak-scout` subagent (`../../agents/ssak-scout.md`) with the "Scout brief", all in parallel. Skip this step when every issue names them.
3. Group coupled issues, using the scout maps where you have them: one needs another's change, or they would change the same files or functions. Separate workers on coupled issues design the same code twice and conflict on merge. Every other issue is a group of its own. Pick each group's worker model (see "Worker model"). Tell the user the coupled groups and each group's model in one line before starting.
4. Launch one `ssak-worker` subagent (`../../agents/ssak-worker.md`) per group on its model, all in parallel. A single issue gets the "Worker brief" from `references/templates.md`; a coupled group gets the "Coupled worker brief", and that worker does its issues in order. Include each issue's scout map when there is one. The script already created the worktrees, so do not use the subagent tool's workspace isolation option.
   - When a later issue needs an earlier one's change, its branch is stacked on the earlier branch, and from here on its `<base>` is the earlier branch.
5. Handle each issue independently; never wait on another issue. A coupled worker reports once per issue.
   - If the worker reports `BLOCKED`, that issue ends there without verification.
   - If the worker reports `DONE`, launch `ssak-verifier` (`../../agents/ssak-verifier.md`) with the "Verifier brief".
6. If verification returns `FAIL`, request a rework.
   - Send the "Rework request" to the same worker with a message tool (`SendMessage` / `send_message`). If unavailable, or the worker ran on `sonnet`, start a new worker on the session model and include the previous worker's report.
   - After the rework, verify again with a fresh verifier so it is not anchored on the earlier verdict.
   - At most 2 reworks per issue. If the third verification still fails, the issue ends as FAIL.
7. When every issue is finished:
   1. Compare changed files across the issue branches with `git diff --name-only <base>...<branch>` to find overlaps.
   2. Remove the worktrees but keep the branches, which hold the work: `bash <skill dir>/../ssak-clean-up/scripts/cleanup.sh remove --keep-branch issue-<num>...`. Never pass `--force`; a worktree it skips (uncommitted changes) stays and goes in the report.
   3. Report using the "Final report" format in `references/templates.md`.

## Rules
- Do not push, open PRs, close issues, or comment on issues. The user decides after reading the report.
- The main agent relays the verifier's verdict as is. With two or more issues it does not edit issue branches itself.
- Remove worktrees only through `cleanup.sh remove --keep-branch` as in the steps above, never with `--force`. Never delete issue branches.
