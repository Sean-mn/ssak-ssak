# ssak-review inline template (--comment only)

What gets posted to GitHub with `--comment`: each finding as its own review with one inline comment, plus a body review only with `--summary` or for findings that cannot sit on a diff line. Replace `<...>` with real values. Severity levels are defined in `review-template.md`.

Write in the language of the PR description. In Korean, write in 해요체 (e.g. "통과해요", "추가하면 좋겠어요"), both in comments and the review body.

Write like a human reviewer talking to a teammate: plain sentences, no `[Severity]` tag and no bold title. Carry the severity in the wording, so the author can tell what blocks the merge:
- Critical / High: say it must be fixed before merging (e.g. "머지 전에 꼭 막아야 할 것 같아요").
- Medium: say it is worth fixing in this PR (e.g. "이번 PR에서 같이 고치면 좋겠어요").
- Low: say it is optional (e.g. "급한 건 아니지만 ~하면 좋겠어요").

## Inline comment
One comment per finding, on the line the finding points at. Keep what is visible short; everything else goes in the folded `<details>`.
````
<What goes wrong and the impact, then how urgent it is, in 1-2 sentences.>

```suggestion
<replacement lines>
```

<details><summary><"Evidence and checks" in the comment's language, e.g. 근거와 확인 내용></summary>

- <why it happens>
- <inputs or cases that reproduce it>
- <other places with the same problem, as path:line>
- <related follow-ups, e.g. tests to add>
</details>
````
- Use the `suggestion` block only when the fix replaces the commented lines. Otherwise write the fix as one line instead, starting with "Fix:" in the comment's language (e.g. `수정:`).
- Leave `<details>` out when there is nothing more to say than the visible lines.

Example (Korean):
````
`ㅤ`(U+3164) 같은 채움 문자만으로 팀 이름을 만들 수 있어요. 급한 건 아니지만 패턴에 같이 막아두면 좋겠어요.

```suggestion
@Pattern(regexp = "(?sU).*[^\\s\\p{Cf}\\u115F\\u1160\\u3164\\uFFA0\\u2800].*", message = "팀 이름은 공백일 수 없습니다.")
```

<details><summary>근거와 확인 내용</summary>

- `(?sU).*\S.*`는 Unicode White_Space만 공백으로 봐요.
- 통과하는 문자: U+3164, U+200B, U+FEFF, U+2800, U+115F, U+1160
- 같은 문제: `ValidChannelName.kt:13`, `ValidProjectName.kt:13`
- 테스트의 공백 목록에 `"ㅤ"`도 추가하면 좋겠어요.
</details>
````

## Review body
### Without `--summary` (default)
No body review. Exception: findings that could not be placed on a diff line go in one body review, each in the inline comment format starting with `path:line`.

### With `--summary`
```
## ssak-review (effort: <level>)
<Verdict line, e.g. "머지를 막을 문제는 없어요. 선택 사항인 Low 1건만 있어요.">

| 🔴 Critical | 🟠 High | 🟡 Medium | ⚪ Low |
|---|---|---|---|
| <n> | <n> | <n> | <n> |

<Findings that could not be placed on a diff line, in the inline comment format, each starting with `path:line`.>

### Checks
- Lint: <command> → <result>
- Build / type check: <command> → <result, or "not run at this effort">
- Tests: <command> → <result, or "not run at this effort">
- Team rules checked: <files read, or "none found">
- Pre-existing: <lint errors on lines the PR did not change, or "none">

<One short paragraph: what else was checked and found fine, and what was not checked (e.g. no HTTP request against a running app).>
```
