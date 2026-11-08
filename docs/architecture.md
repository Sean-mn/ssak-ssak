# Architecture

ssak-ssak is a set of instructions plus small scripts. The main agent (Claude Code or
Codex) reads a `SKILL.md`, runs its scripts for anything that must be exact or safe,
and hands parts of the work to subagents defined in `agents/`.

## Layers

| Layer | Files | Job |
| --- | --- | --- |
| Skill | `skills/<name>/SKILL.md` | The steps the main agent follows: parse arguments, ask, run scripts, launch subagents, report. |
| References | `skills/<name>/references/*.md` | Templates the skill fills in: agent briefs, report and comment formats, checklists. Loaded only when a step needs them. |
| Scripts | `skills/<name>/scripts/*.sh` | Everything that must be deterministic or must refuse unsafe input: creating worktrees, finding issues, posting reviews, pushing, cleanup. |
| Subagents | `agents/*.md` | One job each, with fixed model, effort and tools in frontmatter. They report back in a fixed English format. |
| Manifests | `.claude-plugin/`, `.codex-plugin/`, `.agents/plugins/` | Plugin and marketplace metadata. Claude Code finds `agents/` and `skills/` on its own; Codex reads `skills` from its manifest. |

Skills share scripts across folders: `ssak-contrib` uses `ssak-issue`'s
`find-issues.sh` and `common.sh`, and `ssak-issue` and `ssak-review` call
`ssak-clean-up`'s `cleanup.sh`. Paths in a skill are relative to its own folder.

## Subagents

| Agent | Used by | Model / effort | Writes files | Job |
| --- | --- | --- | --- | --- |
| `ssak-worker` | ssak-issue (2+ issues) | inherit / medium | yes, in its worktree | Implements one issue or a coupled group, commits, reworks on FAIL. |
| `ssak-verifier` | ssak-issue, ssak-contrib | sonnet / high | no | Checks requirements, runs test/build/lint, returns PASS or FAIL. |
| `ssak-scout` | ssak-issue (2+ issues) | sonnet / medium | no | Maps an issue to the files and functions it would change, so coupled issues go to one worker. |
| `ssak-reviewer` | ssak-review (2+ PRs) | inherit / session | no | Reviews one PR in its worktree and returns the report. Starts without CLAUDE.md. |
| `ssak-refuter` | ssak-review at `xhigh` | inherit / medium | no | Tries to disprove one Critical or High finding. Starts without CLAUDE.md. |

When an agent is not registered (e.g. in Codex), the skill reads the agent file and
passes its instructions with the brief to a general-purpose subagent. Subagents cannot
launch subagents, so the main agent runs every fan-out (scouts, workers, verifiers,
refuters).

## Where work happens

| Skill | Location | Created by | Removed by |
| --- | --- | --- | --- |
| ssak-issue | `.claude/worktrees/ssak-issue-<n>` on the repo's branch convention (default `ssak/issue-<n>`) | `make-worktrees.sh` | `cleanup.sh remove --keep-branch issue-<n>` |
| ssak-review | `.claude/worktrees/ssak-review-<pr>`, detached at the PR head | `pr-worktree.sh` | `cleanup.sh remove review-<pr>` |
| ssak-contrib | a clone next to the current repo (or the current repo if it already is one), branch `ssak/contrib-<n>` | `setup-fork.sh` | `/ssak-clean-up` run inside that clone |

The scripts add `.claude/worktrees/` to `.git/info/exclude`, so worktrees never show in
the main checkout's `git status`. Agents work only inside their worktree and never
touch the main checkout.

## Flows

**ssak-issue**, two or more issues: scout each issue → group coupled issues → one
worker per group in parallel → a fresh verifier per issue → up to 2 reworks on FAIL →
final report → remove worktrees, keep branches. With one issue the main agent does the
work itself and still runs a verifier. With `--herdr`, workers run as Claude Code panes
in Herdr instead of subagents; verifiers stay subagents.

**ssak-review**: `pr-worktree.sh` → review at the chosen effort (one reviewer per PR
when there are several) → at `xhigh`, refuters for Critical and High findings → chat
report, or inline comments through `post-review.sh` with `--comment` → cleanup.

**ssak-contrib**: `guidelines.sh` and `issue-status.sh` (read only) → pre-flight
summary, user confirms → `setup-fork.sh` → implement → verifier with the repo's rules →
PR draft, user confirms → `open-pr.sh` opens a draft PR.

**ssak-ci-doctor**: failing checks → annotations and logs → first real error of each →
PR-caused, base already failing, flaky or config → suggested fix → for PR causes, user
confirms → fix and a local commit on the PR branch (never pushed).

**ssak-herdr**: inside a Herdr pane only. Splits a sibling pane, starts Claude Code
there with the given model and effort, hands it the task; `list`, `read` and `send`
check on it.

**ssak-clean-up**: `cleanup.sh scan` marks each worktree and branch SAFE or RISKY →
user picks → `cleanup.sh remove`.

## Safety boundaries

The scripts are where the skills enforce safety, so a confused agent cannot get around
them:

- `post-review.sh` posts only `COMMENT` reviews, only on the current PR head, and only
  once per head.
- `open-pr.sh` pushes only to the fork, never force-pushes, and always opens a draft.
- `cleanup.sh` re-checks every id before removing it and skips RISKY items unless
  `--force`.
- `make-worktrees.sh` is the only way ssak-issue creates worktrees, so branch names
  follow the repo's convention.
