---
name: ssak-orchestrate
description: Open a new Claude Code pane in Herdr and hand it a task, so the main agent stays free and the user can watch or steer the new session. Also lists, reads and prompts the panes it started. Only inside a Herdr pane (HERDR_ENV=1). Use for "/ssak-orchestrate medium <task>", "/ssak-orchestrate sonnet low <task>", "/ssak-orchestrate list", "/ssak-orchestrate read <name>" or "open a new claude window in herdr and do X".
argument-hint: "[model] [low|medium|high|xhigh|max] <task> [--name <name>] | list | read <name> | send <name> <text>"
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
   - Effort: the next word if it is an effort level. Otherwise this session's own effort, from `echo "$CLAUDE_EFFORT"`. If that is empty, leave `--effort` out of step 5 so the pane uses the user's default.
   The task is everything after these words.
2. Name: `--name` if given, otherwise a short kebab-case name from the task (e.g. `fix-login`), matching `[a-z][a-z0-9_-]{0,31}`. If `herdr agent list` already has it, add `-2`, `-3`...
3. Where: the current directory. If the task edits files and another agent is already editing this checkout, say so in one line and suggest a git worktree before starting, since two agents in one checkout overwrite each other.
4. Give it a pane as in "When panes come one at a time" in `references/herdr.md`, with `--cwd "$PWD"`. New tabs are labelled `ssak-orchestrate-<n>`.
5. Start Claude Code in it with the model and effort from step 1 (drop `--effort <effort>` if step 1 found none), and hand over the task, as in "Starting and prompting an agent". A long task goes in `herdr-<name>.md` in a fresh `mktemp -d` directory.
6. Tell the user in two lines: the agent name, pane ID, model and effort, and that `/ssak-orchestrate read <name>` shows its progress. Do not wait for it to finish unless the user asked.

## `list`
Run `herdr agent list` and show each agent's name, pane and state (`working`, `idle`, `done`, `blocked`, `unknown`).

## `read <name>`
1. `herdr agent get <name>` for the state, then `herdr agent read <name> --source recent-unwrapped --lines 120`.
2. Summarize what it did and where it stands. If it is `blocked`, show the question it asks and let the user answer.

## `send <name> <text>`
Prompt it as in step 4 of "Starting and prompting an agent" in `references/herdr.md`.

## Rules
- Close only panes this skill started, and only when the user asks, as in "Closing" in `references/herdr.md`.
- Never answer a `blocked` agent's approval or question on the user's behalf.
