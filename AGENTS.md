# AGENTS.md

Operating guide for AI coding agents (and humans) working in this repository. Read
this first; follow links only when the task needs them.

## What ssak-ssak is

A plugin for Claude Code, Codex and Antigravity (agy): skills and subagents for GitHub work. That covers
issue work in parallel worktrees, PR review, CI failure triage, open source
contributions, Herdr panes and cleanup. There is no app here. The product is the
Markdown instructions in `skills/` and `agents/` and the bash scripts beside them.

**An agent following these skills must never lose the user's work or write to GitHub in
a way the user did not approve. When uncertain, stop and ask; never guess.**

## Where things are

| Need | Go to |
| --- | --- |
| How skills, agents, scripts and worktrees fit together | [`docs/architecture.md`](docs/architecture.md) |
| Rules for writing a SKILL.md, an agent file or a script | [`docs/authoring.md`](docs/authoring.md) |
| Cutting a release | [`docs/releasing.md`](docs/releasing.md) |
| Skills (one folder each: `SKILL.md`, `scripts/`, `references/`) | [`skills/`](skills/) |
| Subagents (worker, verifier, scout, reviewer, refuter) | [`agents/`](agents/) |
| Skill trigger evals | [`evals/`](evals/) |
| Script tests (offline, throwaway git repo) | [`tests/run.sh`](tests/run.sh) |
| Static checks: manifests, frontmatter, README rows, file references | [`.github/check.py`](.github/check.py) |
| Plugin manifests | `.claude-plugin/`, `.codex-plugin/`, `.antigravity-plugin/`, `.agents/plugins/` |

Do not load the whole repository into context. Read the skill you are changing, the
agents and scripts it points at, and the tests that cover them.

## Working loop

1. **Discover:** `git status`, current branch, open PRs (`gh pr list`), the issue.
2. **Understand:** read the skill and every file it references. A rule often lives in
   two places, e.g. a skill and its agent, or a skill and `references/templates.md`.
   Change both.
3. **Plan the smallest change** that is one logical unit. If it mixes concerns, split it.
4. **Implement** on a branch named `<type>/<short-slug>` from an up-to-date `main`.
5. **Verify:**
   - `python .github/check.py` (needs PyYAML)
   - `bash tests/run.sh`
   - `shellcheck -S warning -x skills/*/scripts/*.sh tests/*.sh .github/*.sh` when a script changed
   - If a skill's `description` changed: `claude plugin eval . --runs 1 --ablation none --no-publish`

   Fix root causes; never weaken a check or a test.
6. **Commit** as `<type>: <what changed>`, type `feat`, `fix`, `docs`, `ci`, `test`,
   `refactor` or `chore`. The PR title uses the same format; squash merge turns it into
   the commit subject, and release notes group by its type.
7. **PR:** `gh pr create` filling `.github/PULL_REQUEST_TEMPLATE.md` (Summary,
   Changes, Testing, Checklist).
8. **CI green → merge** with squash. CI runs check.py and shellcheck, then
   `tests/run.sh` on Ubuntu, Windows (Git Bash) and macOS (bash 3.2).

## Hard rules

### Safety of what the skills do

- GitHub writes go only through the skill's script: `post-review.sh` posts reviews and
  `open-pr.sh` pushes and opens contrib PRs. Never tell an agent to call
  `gh pr review`, `gh pr create` or `git push` directly where a script exists. When a
  new write is needed, add a script that refuses unsafe input and test it.
- Worktrees and `ssak/*` branches are removed only through `cleanup.sh`. Never
  `rm -rf`, and never `--force` without the user's confirmation for that item.
- Never write instructions that approve, merge or close PRs, delete remote branches,
  force-push, or push to an upstream the user does not own.
- Subagents that check (verifier, scout, reviewer, refuter) never modify files. Keep
  their `tools` read-only in frontmatter, and say so in their "Do not" section.
- Stop and ask before anything the user did not ask for: claiming an issue, posting,
  removing a RISKY item.

### Git

- One logical change = one commit = one PR. No unrelated changes in a PR.
- Leave the version alone. Only a `release vX.Y.Z: <highlights>` PR changes it, in
  `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json` and `.antigravity-plugin/plugin.json` (`pr-title.sh` enforces this).
- Never use `--no-verify`, never force-push `main`, never merge with failing checks.
- **Never add `Co-Authored-By` or any AI attribution trailer** to commits or PRs. Use
  the repository's configured Git identity; never change it.
- Fixes to merged work go in a new commit and a new PR.

### Content

- Skill and agent instructions are in English. Agents report in English; the main
  agent talks to the user in the user's language. GitHub comments use the language of
  the PR or issue.
- New or changed command: update the skills table in both `README.md` and
  `README.ko.md` (check.py fails otherwise).
- Every path a skill names (`scripts/x.sh`, `references/y.md`, `../../agents/z.md`)
  must exist relative to the skill folder (check.py checks this).
- Scripts must run on bash 3.2 (macOS), Git Bash on Windows and Linux. See
  [`docs/authoring.md`](docs/authoring.md#scripts) for the traps that broke them before.
- Documentation is part of the change: update the README, the docs here and the
  skill's references that your change makes stale.

## Decision-making

- If a request would let a skill lose user work or write to GitHub unasked, do not
  silently comply. Explain the conflict and propose a safer alternative.
- If two approaches are plausible, pick the one that is easier for an agent to follow
  without judgment calls, and say why in the PR.
- Low confidence: choose the safer, reversible option and say so.
