# ssak-ssak

개인 Claude Code 하네스 (플러그인).

## 설치
```
/plugin marketplace add <이 레포 경로 또는 GitHub owner/repo>
/plugin install ssak-ssak@ssak-ssak
```

## 스킬
- `/ssak-issue <issue-num> [issue-num...]`: GitHub 이슈 작업. 1개면 메인이 직접, 2개 이상이면 이슈별 worktree에서 `ssak-worker`가 작업하고 `ssak-verifier`가 검증한 뒤 보고한다.
