# ssak-review inline template (--comment only)

What gets posted to GitHub with `--comment`: one inline comment per finding, plus a review body only with `--summary`. Replace `<...>` with real values. Severity levels are defined in `review-template.md`.

Write in the language of the PR description. In Korean, write in 해요체 (e.g. "통과해요", "추가하면 좋겠어요"), both in comments and the review body.

## Inline comment
One comment per finding, on the line the finding points at. Keep what is visible short; everything else goes in the folded `<details>`.
````
**[<Severity>] <short title>**

<What goes wrong and the impact, in 1 sentence.>

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
**[Low] 보이지 않는 문자만으로 된 이름이 통과해요**

`ㅤ`(U+3164) 같은 채움 문자만으로 팀 이름을 만들 수 있어요.

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
No body. Exception: findings that could not be placed on a diff line go in the body, each in the inline comment format with `path:line` added to the title.

If GitHub rejects an empty body, use one line instead:
```
ssak-review (effort: <level>): <n> inline comment(s)
```

### With `--summary`
```
## ssak-review (effort: <level>)
<Verdict line, e.g. "머지를 막을 문제는 없어요. 선택 사항인 Low 1건만 있어요.">

| 🔴 Critical | 🟠 High | 🟡 Medium | ⚪ Low |
|---|---|---|---|
| <n> | <n> | <n> | <n> |

<Findings that could not be placed on a diff line, in the inline comment format with `path:line` added.>

### Checks
- Lint: <command> → <result>
- Build / type check: <command> → <result, or "not run at this effort">
- Tests: <command> → <result, or "not run at this effort">
- Team rules checked: <files read, or "none found">
- Pre-existing: <lint errors on lines the PR did not change, or "none">

<One short paragraph: what else was checked and found fine, and what was not checked (e.g. no HTTP request against a running app).>
```
