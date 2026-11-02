---
name: ssak-clean-up
description: Clean up what the ssak skills leave in the current repo, i.e. ssak-issue and ssak-review worktrees under .claude/worktrees and ssak/issue-N and ssak/contrib-N branches. Lists each item as SAFE (nothing would be lost) or RISKY, and removes only what the user approves. Use for "/ssak-clean-up" or "clean up ssak worktrees".
argument-hint: "[id...]"
---

# ssak-clean-up

Arguments: `$ARGUMENTS`

Paths below are relative to this skill's base directory (shown when the skill loads).
- `scripts/cleanup.sh scan`: one line per item, `<id> <SAFE|RISKY> wt=<path|-> branch=<name|-> | <notes>`. Ids look like `issue-12`, `review-42`, `contrib-7`.
- `scripts/cleanup.sh remove [--force] <id>...`: re-checks each id and removes its worktree and local branch. RISKY ids are skipped unless `--force`.

SAFE means removing loses nothing: no uncommitted changes and every branch commit is on a remote. RISKY means uncommitted changes, commits that exist only locally, or a branch checked out somewhere.

## Steps
1. Check the current directory is a git repo. Run `bash <skill dir>/scripts/cleanup.sh scan`. If it prints `nothing to clean`, say so and stop.
2. Show the user a table grouped SAFE first, then RISKY:

   | Id | Status | Worktree | Branch | Notes |
   |---|---|---|---|---|

   Shorten worktree paths to the part after the repo root. Notes include the PR state when there is one (`PR #12 MERGED`).
3. Ask what to remove:
   - If ids were passed as arguments, propose exactly those.
   - Otherwise propose all SAFE ids.
   - A RISKY id is removed only if the user names it and confirms they accept losing what its notes say (uncommitted changes, local-only commits). Ask about each RISKY id separately.
4. Run `cleanup.sh remove <SAFE ids>`, and `cleanup.sh remove --force <confirmed RISKY ids>` as a separate call.
5. Report what was removed and what was kept and why. For a branch kept because it is checked out, tell the user to switch to another branch first.

## Rules
- Only use `cleanup.sh`. Never delete worktrees or branches with other commands, never `rm -rf` a folder.
- Never delete remote branches, close PRs, or touch anything outside the current repo. If pushed `ssak/*` branches remain on the remote, mention them and the command `git push origin --delete <branch>` without running it.
- `ssak-contrib` clones live in their own folders. To clean those, run this skill inside that clone.
