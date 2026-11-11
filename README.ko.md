[English](README.md) | 한국어

# ssak-ssak

Claude Code와 Codex용 개인 스킬 하네스: 이슈 작업, PR 리뷰, 오픈소스 기여, 정리.

[![version](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2FSean-mn%2Fssak-ssak%2Fmain%2F.claude-plugin%2Fplugin.json&query=%24.version&label=version&color=blue)](.claude-plugin/plugin.json)
[![Claude Code](https://img.shields.io/badge/Claude_Code-plugin-D97757)](#claude-code)
[![Codex](https://img.shields.io/badge/Codex-plugin-412991)](#codex)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 빠른 시작

`git`, `bash`(Windows는 Git Bash), `gh auth login`으로 로그인한 [GitHub CLI](https://cli.github.com/)가 필요해요.

### Claude Code

```
/plugin marketplace add Sean-mn/ssak-ssak
/plugin install ssak-ssak@ssak-ssak
```

업데이트: `/plugin marketplace update ssak-ssak` 실행 후 `/plugin`에서 플러그인을 업데이트하고 재시작해요.

### Codex

```bash
codex plugin marketplace add Sean-mn/ssak-ssak
codex plugin add ssak-ssak@ssak-ssak
```

업데이트: `codex plugin marketplace upgrade`

## 스킬

| 명령 | 하는 일 |
|---|---|
| `/ssak-issue <issue#> [issue#...]` | GitHub 이슈를 작업하고 검증 에이전트가 확인해요. 2개 이상이면 이슈별 worktree에서 병렬로 작업해요. 먼저 정찰 에이전트가 이슈마다 건드릴 파일을 찾아서, 겹치는 이슈는 한 워커에게 맡겨요. 서로 의존하는 이슈(GitHub "blocked by" 링크나 "depends on #N")는 쌓인 브랜치에서 순서대로 작업하고, 이번 실행에 없는 열린 의존 이슈가 있으면 먼저 물어봐요. |
| `/ssak-issue <issue#>... --pr` | 같은 작업 후 검증을 통과한 이슈마다 PR 초안을 보여주고, 승인하면 draft PR로 열어요. |
| `/ssak-issue --find` | 아무도 맡지 않은 열린 이슈를 보여줘요. |
| `/ssak-issue <issue#> <issue#>... --herdr [model] [effort]` | 같은 작업을 하되, 워커마다 Herdr에 Claude Code 창을 따로 띄워서 직접 보고 끼어들 수 있어요. effort를 빼면 메인 에이전트가 이슈 난이도를 보고 이슈마다 골라요. |
| `/ssak-orchestrate [model] [effort] <task> [--no-wait]` | Herdr에 새 Claude Code 창을 띄우고 작업을 맡겨요. 모델이나 effort를 빼면 메인 창의 값을 써요. 백그라운드로 기다렸다가 끝나면 결과를 알려주고, `--no-wait`이면 띄우기만 해요. `list`, `read <name>`, `send <name> <text>`로 진행 상황을 봐요. Herdr가 필요해요. |
| `/ssak-review [low\|medium\|high\|xhigh] <pr#> [pr#...] [--comment] [--summary]` | 운영 영향, lint, 팀 규칙 중심으로 PR을 리뷰해요. effort를 생략하면 medium으로 시작하고, 위험한 PR(마이그레이션, auth, 인프라, 큰 diff)은 high로 올려요. 2개 이상이면 PR마다 리뷰 에이전트가 병렬로 리뷰해요. `--comment`면 인라인 코멘트를 달아요. |
| `/ssak-ci-doctor [owner/repo] [pr#]` | PR의 CI가 왜 실패했는지 찾아요. 실패한 체크마다 첫 진짜 에러, PR 탓인지 여부, 고칠 방법을 알려줘요. 번호를 빼면 방금 작업한 PR이나 현재 브랜치의 PR을 봐요. PR 탓인 실패는 승인하면 PR 브랜치에 로컬 커밋으로 고쳐요. push는 하지 않아요. |
| `/ssak-contrib <owner/repo> <issue#>` | 레포의 기여 규칙과 AI 정책을 지켜 오픈소스에 기여하고, 승인을 받은 뒤 draft PR을 열어요. |
| `/ssak-contrib <owner/repo> --find` | 아무도 맡지 않은 입문자용 이슈를 보여줘요. |
| `/ssak-clean-up [id...]` | 스킬들이 남긴 worktree와 브랜치를 정리해요. 지우기 전에 물어봐요. |

Claude Code에서는 명령이 `/ssak-ssak:ssak-issue`처럼 보일 수 있어요. Codex에서는 이름으로 요청하면 돼요. 예: "ssak-issue --find 써줘".
