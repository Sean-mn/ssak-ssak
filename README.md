English | [한국어](README.ko.md)

# ssak-ssak

Personal skill harness for Claude Code and Codex: issue work, PR review, open source contributions and cleanup.

[![version](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2FSean-mn%2Fssak-ssak%2Fmain%2F.claude-plugin%2Fplugin.json&query=%24.version&label=version&color=blue)](.claude-plugin/plugin.json)
[![Claude Code](https://img.shields.io/badge/Claude_Code-plugin-D97757)](#claude-code)
[![Codex](https://img.shields.io/badge/Codex-plugin-412991)](#codex)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)



</div>

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
| `/ssak-issue <issue#> [issue#...]` | Works on GitHub issues, each checked by a verifier agent. Two or more run in parallel worktrees. |
| `/ssak-issue --find` | Lists open issues nobody has taken yet. |
| `/ssak-review [low\|middle\|high\|xhigh] <pr#> [pr#...] [--comment] [--summary]` | Reviews PRs for production impact, lint and team rules. Two or more are reviewed in parallel, one reviewer agent per PR. `--comment` posts inline comments. |
| `/ssak-ci-doctor [owner/repo] <pr#>` | Finds why CI failed on a PR: the first real error of each failing check, whether the PR caused it, and the fix. Read-only. |
| `/ssak-contrib <owner/repo> <issue#>` | Contributes to an open source repo by its rules and AI policy, then opens a draft PR after you approve. |
| `/ssak-contrib <owner/repo> --find` | Lists beginner-friendly issues nobody has taken. |
| `/ssak-clean-up [id...]` | Removes worktrees and branches the skills left behind. Asks first. |

In Claude Code a command may show as `/ssak-ssak:ssak-issue`. In Codex, ask by name, e.g. "use ssak-issue --find".
