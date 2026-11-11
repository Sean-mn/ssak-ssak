---
name: ssak-orchestrate
description: Open a new Claude Code pane in Herdr and hand it a task, so the main agent stays free and the user can watch or steer the new session. Also lists, reads and prompts the panes it started. Only inside a Herdr pane (HERDR_ENV=1). Use for "/ssak-orchestrate medium <task>", "/ssak-orchestrate sonnet low <task>", "/ssak-orchestrate list", "/ssak-orchestrate read <name>" or "open a new claude window in herdr and do X".
argument-hint: "[model] [low|medium|high|xhigh|max] <task> [--name <name>] [--no-wait] | list | read <name> | send <name> <text>"
# for: Opus 5.5 / Sonnet 5.5 as the main agent; not checked on Haiku
---

# ssak-orchestrate

Arguments: `$ARGUMENTS`

Paths below are relative to this skill's base directory (shown when the skill loads).
- `references/herdr.md`: how to lay out, start, prompt, watch and close Herdr panes. Read it before any `herdr` command; the steps below follow it.

## 0. Prepare
1. Do the checks in "Before anything" in `references/herdr.md`.
2. Pick the mode from the first argument: `list`, `read <name>`, `send <name> <text>`, otherwise a new task. An empty argument: show the usage from `argument-hint` and stop.

## New task
1. Model and effort, from the leading words. Effort levels are `low`, `medium`, `high`, `xhigh`, `max`.
   - Model: the first word if it is a model alias (`opus`, `sonnet`, `fable`, `haiku`) or a full model ID (`claude-...`). Otherwise this session's own model (its full model ID, e.g. `claude-opus-5-5`), so the new pane does not fall back to the user's default model.
   - Effort: the next word if it is an effort level. Otherwise this session's own effort, from `echo "$CLAUDE_EFFORT"`. If that is empty, leave `--effort` out of step 6 so the pane uses the user's default.
   The task is everything after these words, minus `--name <name>` and `--no-wait`.
2. Name: `--name` if given, otherwise a short kebab-case name from the task (e.g. `fix-login`), matching `[a-z][a-z0-9_-]{0,31}`. If `herdr agent list` already has it, add `-2`, `-3`...
3. Where: the current directory. If the task edits files and another agent is already editing this checkout, say so in one line and suggest a git worktree before starting, since two agents in one checkout overwrite each other.
4. Give it a pane as in "When panes come one at a time" in `references/herdr.md`, with `--cwd "$PWD"`. New tabs are labelled `ssak-orchestrate-<n>`.
5. Write the task file: make a fresh `mktemp -d` directory, and in it `herdr-<name>.md` holding the task, then the "Report request" below with `<report path>` set to `herdr-<name>.report.md` in the same directory.
6. Start Claude Code in it with the model and effort from step 1 (drop `--effort <effort>` if step 1 found none), and prompt `Read <task file path> and follow it.`, as in "Starting and prompting an agent".
7. Tell the user in two lines: the agent name, pane ID, model and effort, the report path, and either that you will report back when it finishes or, with `--no-wait`, that `/ssak-orchestrate read <name>` shows its progress.
8. Unless `--no-wait`, wait for the result as in "Waiting for the result". With `--no-wait`, stop here.

### Report request
Append this to the task file:
```
When the task is done, or you cannot go on without the user, write your report to <report path> in this format, then reply only "REPORTED". Write the report in English.
STATUS: DONE | BLOCKED | FAILED
Summary: <what you did, 1-3 lines>
Changes: <files changed, commits made, or "none">
Checks: <commands run and their result, or "none">
Needs the user: <question or decision, or "none">
```

### Waiting for the result
The main pane stays free while it waits: keep talking with the user meanwhile.
1. Run `herdr agent wait <name>` in the background, as in "Watching" in `references/herdr.md`, and never poll. If this session cannot run a command in the background and be told when it ends, say so in one line and treat the run as `--no-wait`.
2. When the wait ends:
   - `blocked`: show the user the question from `herdr agent read <name> --lines 40`, and wait again after they answer it in the pane or through `send`.
   - `idle` or `done` with the report file present: the agent is finished. Go to step 3.
   - `idle` or `done` without it: `idle` also means the agent stopped to ask something. Read `herdr agent read <name> --source recent-unwrapped --lines 120`. If it asks the user something, show the question; if it is still mid-task, wait again.
3. Read the report and tell the user, in their language: STATUS, summary, changes and checks, and anything under "Needs the user". With two or more agents waiting, report each one as it finishes; never hold one back for the others. On `BLOCKED`, once the user has answered, delete the report file and wait again from step 1.
4. Otherwise delete the agent's handoff files and their directory, as in "Handoff files" in `references/herdr.md`.
5. Leave the pane open, so the user can keep working with that session. Mention `/ssak-orchestrate send <name> <text>` for follow-ups.

## `list`
Run `herdr agent list` and show each agent's name, pane and state (`working`, `idle`, `done`, `blocked`, `unknown`).

## `read <name>`
1. `herdr agent get <name>` for the state, then `herdr agent read <name> --source recent-unwrapped --lines 120`. If its report file exists (the path from step 7 of "New task"), read that too.
2. Summarize what it did and where it stands, from the report when there is one. If it is `blocked`, show the question it asks and let the user answer. If it is finished (report file present), delete its handoff files as in step 4 of "Waiting for the result".

## `send <name> <text>`
Prompt it as in steps 3 and 4 of "Starting and prompting an agent" in `references/herdr.md`, putting a long text in a file as in step 5 of "New task".

## Rules
- Close only panes this skill started, and only when the user asks, as in "Closing" in `references/herdr.md`.
- Never answer a `blocked` agent's approval or question on the user's behalf.
- An agent is finished only when its report file exists; `idle` alone is not enough.
