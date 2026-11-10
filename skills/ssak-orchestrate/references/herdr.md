# Herdr panes

How the ssak skills open, lay out, prompt and close Claude Code panes in Herdr. Used by `ssak-orchestrate` and `ssak-issue --herdr`; each skill says what it names the agents and what it hands them.

## Before anything
- Run `test "${HERDR_ENV:-}" = 1`. If it fails, say this session is not inside a Herdr pane and stop. Never control a Herdr session from outside it. If `command -v herdr` fails, say Herdr is not installed and stop.
- The installed `herdr` binary is the authority for syntax: if a command fails with a usage error, check `herdr <group> --help`. Never run bare `herdr`, which opens the TUI.
- Read pane, tab and agent IDs from the JSON responses, never guess them.
- Pass `--no-focus` to every split and tab; the user moves focus themselves.

## Layout
The calling session is the main pane: the user talks to it, so it stays on the left at full height and never shrinks after the first split.
- Main tab: up to 3 task panes, stacked evenly in one column on the main pane's right. If `herdr pane layout --pane "$HERDR_PANE_ID"` shows the main pane taller than wide, the column sits below it instead: swap `right` and `down` throughout.
- More than 3: new tabs of up to 9 panes each, in a 3×3 grid. `herdr tab create --label <skill>-<n> --cwd <dir> --no-focus` gives the tab's first pane at `.result.root_pane.pane_id`. A tab closes by itself when its last pane closes.

Splitting: `herdr pane split --pane <id> --direction <right|down> --ratio <r> --cwd <dir> --no-focus`. The new pane ID is `.result.pane.pane_id`. `--ratio` is the share the split pane keeps (the left or top part). To cut a pane into k even parts, split it with `1/k`, then the new pane with `1/(k-1)`, and so on (k = 3: `0.333`, then `0.5`). Every split passes the `--cwd` of the agent it is for.

### When the number of panes is known
Plan the whole layout before the first split, since even sizes need the counts.
- Panes 1-3: split the main pane `right` with `0.5`, then split each new pane `down` into the column's count (2: `0.5`; 3: `0.333`, then `0.5`).
- Panes 4 and on, 9 per tab: for a tab's m panes, split its first pane `right` into ceil(m/3) columns, then each column `down` into its rows, filling columns of 3 in order (m = 5: two columns, 3 and 2 rows).

### When panes come one at a time
Count the named agent panes (`herdr agent list`) in the main pane's tab, leaving out the main pane.
- None: split the main pane `right` with `0.5`.
- 1 or 2: split the tallest of them `down` with `0.5`, so the main pane keeps its size.
- 3: use the newest `<skill>-<n>` tab (`herdr tab list`) with fewer than 9 panes, and split its largest pane with `0.5`, `right` when it is more than twice as wide as tall in cells, otherwise `down`. If there is none, create the next tab.

### Replacing a pane
To put a new session where an old one was, split the old pane `down` with `0.5`, then close the old pane; the new one takes its space.

## Starting and prompting an agent
1. Start Claude Code in the pane: `herdr agent start <name> --kind claude --pane <pane id> -- --model <model> --effort <effort> -n <name>`. Always pass the model, so the pane does not fall back to the user's default.
2. On `agent_not_ready` (a startup dialog such as folder trust), read it with `herdr agent read <name> --lines 40`, tell the user what it asks, and let them answer it in the pane.
3. Text longer than a couple of lines goes in a file first, so quoting cannot break it, and the prompt says `Read <path> and follow it.`
4. `herdr agent prompt <name> "<text>" --wait --timeout 60000`. The wait only confirms the session started working. A `timeout` or `agent_prompt_stalled` does not mean the prompt was lost: check `herdr agent read <name> --lines 40` before sending anything again. On `agent_blocked`, show the pending question instead of sending.
5. The main pane can prompt a running agent at any time, e.g. to ask how it is going; the message is taken after the agent's current step. Read the answer with `herdr agent read <name> --source recent-unwrapped --lines 120`.

## Watching
- `herdr agent wait <name>` settles on `idle`, `done` or `blocked`. Run it in the background and never poll.
- `idle` does not mean the task is finished: an agent that stops to ask something is `idle` too. Each skill has its agent write a report file, and only that file means it is done.
- `herdr agent get <name>` gives the state; `herdr agent list` gives every agent's name, pane and state (`working`, `idle`, `done`, `blocked`, `unknown`).
- On `blocked`, show the user the question from `herdr agent read <name> --lines 40`. Never answer an approval or question on the user's behalf.

## Closing
Close only panes this skill run started, with `herdr pane close <pane id>`. Never close other panes, tabs or workspaces, and never run `herdr server stop`.
