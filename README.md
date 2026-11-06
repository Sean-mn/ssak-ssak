English | [한국어](README.ko.md)

# ssak-ssak

Personal skill harness for Claude Code and Codex: issue work, PR review, open source contributions and cleanup.

[![version](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2FSean-mn%2Fssak-ssak%2Fmain%2F.claude-plugin%2Fplugin.json&query=%24.version&label=version&color=blue)](.claude-plugin/plugin.json)
[![Claude Code](https://img.shields.io/badge/Claude_Code-plugin-D97757)](#claude-code)
[![Codex](https://img.shields.io/badge/Codex-plugin-412991)](#codex)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Quick Start

Requires `git`, `bash` (Git Bash on Windows) and the [GitHub CLI](https://cli.github.com/) signed in with `gh auth login`.

### Claude Code

```
/plugin marketplace add Sean-mn/ssak-ssak
/plugin install ssak-ssak@ssak-ssak
```

Update with `/plugin marketplace update ssak-ssak`, then update the plugin from `/plugin` and restart.

### Codex

```bash
codex plugin marketplace add Sean-mn/ssak-ssak
codex plugin add ssak-ssak@ssak-ssak
```

Update with `codex plugin marketplace upgrade`.

## Skills

| Command | What it does |
|---|---|
| `/ssak-issue <issue#> [issue#...]` | Works on GitHub issues, each checked by a verifier agent. Two or more run in parallel worktrees; a scout agent first maps the files each issue touches so overlapping issues go to one worker. |
| `/ssak-issue --find` | Lists open issues nobody has taken yet. |
| `/ssak-issue <issue#> <issue#>... --herdr [model] [effort]` | Same, but each worker runs as its own Claude Code pane in Herdr, so you can watch and steer it. Without an effort, the main agent picks one per issue from how hard it looks. |
| `/ssak-herdr [model] [effort] <task>` | Opens a new Claude Code pane in Herdr and hands it the task. Without a model or effort it uses the main pane's. `list`, `read <name>` and `send <name> <text>` check on it. Needs Herdr. |
| `/ssak-review [low\|medium\|high\|xhigh] <pr#> [pr#...] [--comment] [--summary]` | Reviews PRs for production impact, lint and team rules. With no effort given, starts at medium and moves to high for risky PRs (migrations, auth, infra, large diffs). Two or more are reviewed in parallel, one reviewer agent per PR. `--comment` posts inline comments. |
| `/ssak-ci-doctor [owner/repo] [pr#]` | Finds why CI failed on a PR: the first real error of each failing check, whether the PR caused it, and the fix. Without a number, uses the PR you just worked on or the current branch's. Read-only. |
| `/ssak-contrib <owner/repo> <issue#>` | Contributes to an open source repo by its rules and AI policy, then opens a draft PR after you approve. |
| `/ssak-contrib <owner/repo> --find` | Lists beginner-friendly issues nobody has taken. |
| `/ssak-clean-up [id...]` | Removes worktrees and branches the skills left behind. Asks first. |

In Claude Code a command may show as `/ssak-ssak:ssak-issue`. In Codex, ask by name, e.g. "use ssak-issue --find".
