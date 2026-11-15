# ssak-respond templates

Replace `<...>` with real values. Write messages to the user in the user's language; write replies in the language of the thread.

## Plan (to the user, before any change)
```
## Review comments on PR #<num>: <title>
<url> · <n> open, <n> answered (waiting on the reviewer), <n> resolved

| # | Thread | Reviewer | Group | What I will do |
|---|---|---|---|---|
| 1 | `<path>:<line>` <what the comment asks, one line> | <author> | Fix / Already fixed / Answer / Decline / Ask | <the change and where / the commit that did it / the answer in short / why not, with `path:line` / the question for you> |

**Review bodies** (no thread to reply in): <author>: <what it asks and what I will do, or "nothing to do">. Omit when there is none.
**Checkout**: <ready on <branch> / needs gh pr checkout <num> / not usable: <why>>
```
Then ask whether to go ahead, with every Ask thread's question in the same call.

## Replies
One reply per thread. Short: the reviewer reads many of them. No greeting, no thanks for the review, no apology.

In Korean, write in 해요체 (e.g. "고쳤어요", "그대로 둘게요").

- **Fix**: `Fixed in <short sha>: <what changed, one sentence>.`
- **Already fixed**: `Already handled in <short sha>: <what that commit did, one sentence>.`
- **Answer**: the answer in one to three sentences, with `path:line` when it points at code.
- **Decline**: `Leaving this as is: <the reason, with path:line or the rule it rests on>.` Add what you would do instead when there is something.

Examples (Korean):
```
`a1b2c3d`에서 고쳤어요. 빈 배열이면 0을 반환하도록 했어요.
```
```
그대로 둘게요. 이 값은 `config/limits.ts:14`에서 이미 검증돼서 여기서 다시 확인하지 않아도 돼요.
```

## Reply drafts (to the user, before posting)
```
## Reply drafts for PR #<num>

**Commits** (local, not pushed): <hash subject>, one per line, or "none"
**Checks**: <command> → <result>, or "none run: no code change"

1. `<path>:<line>` to <author>: <group>
   > <the reply>

**Not replied**: <threads left out and why: Ask left undecided, review bodies; "none" if none>
```
Then ask whether to post. When a reply names a commit, say that `git push` comes first.

## Final report
```
## ssak-respond result: PR #<num>
- Fixed: <n> threads in <n> commits (<hashes>)<, not pushed yet: run `git push`>
- Replies posted: <n>, one URL per line / none, and why
- Left for you: <Ask threads undecided, replies the script refused or skipped, review bodies>
- Waiting on the reviewer: <n> answered threads
- Checks: <command> → <result>
```
