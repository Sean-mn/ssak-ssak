[English](README.md) | 한국어

# ssak-ssak

Claude Code와 Codex용 개인 스킬 하네스: 이슈 작업, PR 리뷰, 오픈소스 기여, 정리.

[![version](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2FSean-mn%2Fssak-ssak%2Fmain%2F.claude-plugin%2Fplugin.json&query=%24.version&label=version&color=blue)](.claude-plugin/plugin.json)
[![Claude Code](https://img.shields.io/badge/Claude_Code-plugin-D97757)](#claude-code)
[![Codex](https://img.shields.io/badge/Codex-plugin-412991)](#codex)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)



</div>

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
| `/ssak-issue <issue#> [issue#...]` | GitHub 이슈를 작업해요. 2개 이상이면 이슈별 worktree에서 병렬로 작업하고 검증 에이전트가 확인해요. |
| `/ssak-issue --find` | 아무도 맡지 않은 열린 이슈를 보여줘요. |
| `/ssak-review [low\|middle\|high\|xhigh] <pr#> [--comment] [--summary]` | 운영 영향, lint, 팀 규칙 중심으로 PR을 리뷰해요. `--comment`면 인라인 코멘트를 달아요. |
| `/ssak-contrib <owner/repo> <issue#>` | 레포의 기여 규칙과 AI 정책을 지켜 오픈소스에 기여하고, 승인을 받은 뒤 draft PR을 열어요. |
| `/ssak-contrib <owner/repo> --find` | 아무도 맡지 않은 입문자용 이슈를 보여줘요. |
| `/ssak-clean-up [id...]` | 스킬들이 남긴 worktree와 브랜치를 정리해요. 지우기 전에 물어봐요. |

Claude Code에서는 명령이 `/ssak-ssak:ssak-issue`처럼 보일 수 있어요. Codex에서는 이름으로 요청하면 돼요. 예: "ssak-issue --find 써줘".
