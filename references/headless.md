# Headless workers

How `ssak-issue --headless` starts, waits on and resumes background `claude -p` sessions. Each session runs one worker in its worktree, with no pane and no way to ask the user anything.

## Before anything
- If `command -v claude` fails, say the Claude Code CLI is not installed and stop.
- If this harness cannot run a shell command in the background and notify you when it exits (Claude Code's Bash `run_in_background`), say so and stop.
- If this session is in plan mode, say workers cannot change files in plan mode and stop.

## Permissions
A `claude -p` session cannot ask for approval, so each worker follows this session's permissions:
- Mode: pass `--permission-mode <mode>` with the mode this session runs in, as the harness states it (`acceptEdits`, `auto`, `bypassPermissions`, `dontAsk`, `manual`). If the harness does not say which mode is active, pass no `--permission-mode`; the worker then uses the user's default. Never pass a mode other than this session's, and never pass `--dangerously-skip-permissions`.
- Allow rules: the user's `~/.claude/settings.json` and the repo's committed `.claude/settings.json` load by themselves. `.claude/settings.local.json` is not committed, so the worktree lacks it: if `<main repo>/.claude/settings.local.json` exists, pass `--settings "<that path>"`.
- Approvals the user gave only for this session do not carry over.
- In any mode but `bypassPermissions`, a command outside the allow rules is denied and listed in the output's `.permission_denials`; the worker then stops early or reports `BLOCKED`.

## Starting a worker
Run one background shell command per worker (Bash with `run_in_background`), all in the same response:
```
cd "<worktree path>" && claude -p "Read <brief path> and follow it." --model <model> --effort <effort> [--permission-mode <mode>] [--settings "<main repo>/.claude/settings.local.json"] --add-dir "<main repo>/.claude/worktrees" --add-dir "<plugin root>/agents" -n issue-<num> --output-format json > "<main repo>/.claude/worktrees/ssak-issue-<num>.out.json"
```
- Always pass `--model`, so the worker does not fall back to the user's default.
- Always pass both `--add-dir`: the brief, report and rework files and `ssak-worker.md` sit outside the worktree, and reads outside it are denied otherwise. `<plugin root>` is this skill's base directory up two levels.
- The output file is one JSON object; `.session_id` is needed to resume, `.result` is the worker's last reply.

## Waiting
- The harness notifies you when each command exits. Never poll and never sleep; handle each worker as it finishes, without waiting for the others.
- Only the report file the brief names means the worker is done. A non-zero exit, or an output file that is not JSON, means the worker failed: treat the issue as `BLOCKED` with the command's error output.

## Resuming
To send a worker more (a rework request, the user's answer to its question), write the text to a file, then run in the background, from the same worktree and with the same flags as at the start:
```
cd "<worktree path>" && claude -p "Read <path> and follow it." --resume <session_id> --model <model> --effort <effort> [--permission-mode <mode>] [--settings "<path>"] --add-dir "<main repo>/.claude/worktrees" --add-dir "<plugin root>/agents" --output-format json > "<main repo>/.claude/worktrees/ssak-issue-<num>.out.json"
```
Take `<session_id>` from the output file before the command overwrites it. If resuming fails, start a new worker with the same brief plus the previous report and the new text.

## Handoff files
The brief, rework, report and output files are deleted by the skill at the point its steps name. Delete only those files, each by its exact path with `rm -f <path>`. Never use `rm -r` or a glob. If a worker is still running, do not delete its files; name them in your message to the user.
