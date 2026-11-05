---
name: ssak-herdr
description: Open a new Claude Code pane in Herdr and hand it a task, so the main agent stays free and the user can watch or steer the new session. Also lists, reads and prompts the panes it started. Only inside a Herdr pane (HERDR_ENV=1). Use for "/ssak-herdr medium <task>", "/ssak-herdr sonnet low <task>", "/ssak-herdr list", "/ssak-herdr read <name>" or "open a new claude window in herdr and do X".
argument-hint: "[model] [low|medium|high|xhigh|max] <task> [--name <name>] | list | read <name> | send <name> <text>"
# for: Opus 5.5 / Sonnet 5.5 as the main agent; not checked on Haiku
---

# ssak-herdr

Arguments: `$ARGUMENTS`

The installed `herdr` binary is the authority for syntax: if a command below fails with a usage error, check `herdr <group> --help` (never run bare `herdr`, which opens the TUI).

## 0. Prepare
1. Run `test "${HERDR_ENV:-}" = 1`. If it fails, say this session is not inside a Herdr pane and stop. Never control a Herdr session from outside it. If `command -v herdr` fails, say Herdr is not installed and stop.
2. Pick the mode from the first argument: `list`, `read <name>`, `send <name> <text>`, otherwise a new task. An empty argument: show the usage from `argument-hint` and stop.

## New task
1. Model and effort, from the leading words. Effort levels are `low`, `medium`, `high`, `xhigh`, `max`.
   - Model: the first word if it is a model alias (`opus`, `sonnet`, `fable`, `haiku`) or a full model ID (`claude-...`). Otherwise this session's own model (its full model ID, e.g. `claude-opus-5-5`), so the new pane does not fall back to the user's default model.
   - Effort: the next word if it is an effort level. Otherwise this session's own effort, from `echo "$CLAUDE_EFFORT"`. If that is empty, leave `--effort` out of step 5 so the pane uses the user's default.
   The task is everything after these words.
2. Name: `--name` if given, otherwise a short kebab-case name from the task (e.g. `fix-login`), matching `[a-z][a-z0-9_-]{0,31}`. If `herdr agent list` already has it, add `-2`, `-3`...
3. Where: the current directory. If the task edits files and another agent is already editing this checkout, say so in one line and suggest a git worktree before starting, since two agents in one checkout overwrite each other.
4. Split a sibling pane without moving the user's focus. Split `right` when `herdr pane layout --pane "$HERDR_PANE_ID"` shows the caller is wider than tall, otherwise `down`:
   `herdr pane split --current --direction <right|down> --cwd "$PWD" --no-focus`
   Read the new pane ID from `.result.pane.pane_id`.
5. Start Claude Code in it with the model and effort from step 1 (drop `--effort <effort>` if step 1 found none):
   `herdr agent start <name> --kind claude --pane <pane id> -- --model <model> --effort <effort> -n <name>`
   On `agent_not_ready` (a startup dialog such as folder trust), read it with `herdr agent read <name> --lines 40`, tell the user what it asks, and let them answer it in the pane. Do not answer it yourself.
6. Hand over the task. A task longer than a couple of lines goes in a file first, so quoting cannot break it: write it to `herdr-<name>.md` in a fresh `mktemp -d` directory and prompt `Read <that path> and do what it says.`
   `herdr agent prompt <name> "<task>" --wait --timeout 60000`
   The wait only confirms the new session started working. A `timeout` or `agent_prompt_stalled` does not mean the prompt was lost: check `herdr agent read <name> --lines 40` before sending anything again.
7. Tell the user in two lines: the agent name, pane ID, model and effort, and that `/ssak-herdr read <name>` shows its progress. Do not wait for it to finish unless the user asked.

## `list`
Run `herdr agent list` and show each agent's name, pane and state (`working`, `idle`, `done`, `blocked`, `unknown`).

## `read <name>`
1. `herdr agent get <name>` for the state, then `herdr agent read <name> --source recent-unwrapped --lines 120`.
2. Summarize what it did and where it stands. If it is `blocked`, show the question it asks and let the user answer; do not answer it yourself.

## `send <name> <text>`
`herdr agent prompt <name> "<text>" --wait --timeout 60000`. If it returns `agent_blocked`, show the pending question instead of sending.

## Rules
- Close only panes this skill started, and only when the user asks: `herdr pane close <pane id>`. Never close other panes, tabs or workspaces, and never run `herdr server stop`.
- Use `--no-focus` always; the user moves focus themselves.
- Read IDs from the JSON responses, never guess them.
- Never answer a `blocked` agent's approval or question on the user's behalf.
