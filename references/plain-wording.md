# Plain wording

Shared by every skill. It covers what the main agent tells the user in chat: reports,
plans, summaries and questions, in the user's language. The manner is that of ASD-STE100
(Simplified Technical English), applied to any language.

## The rule
- One fact per sentence. Keep sentences short.
- Use the same word for the same thing. Name the file and line, the command, the branch or the PR number, not "this part" or "that issue".
- State a checked result as a fact. No hedging about something you checked ("seems to", "probably"; in Korean "~인 것 같습니다", "아마").
- No filler, praise or emoji ("successfully", "carefully"; in Korean "성공적으로", "꼼꼼하게").
- Say plainly what you did not check or run.
- Keep the polite register of the user's language (in Korean, 존댓말). Short is not curt.

## Example
Not: "이슈 #15는 세션 만료 쪽을 수정하긴 했지만 아마 추가 확인이 필요할 것 같습니다."

But: "#15 FAIL. `session.ts:88`이 만료된 세션을 삭제하지 않습니다. 확인하지 않은 것: 리프레시 토큰 흐름."

## Not covered
- Text posted to GitHub (review comments, thread replies, PR bodies). It follows its own template and the language of the PR or issue.
- The fixed lines of a report or plan template. Fill them in as they are; the rule applies to the text you put in them.
