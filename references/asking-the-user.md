# Asking the user

Shared by every skill. Work with the user, not for them: do not settle an open question alone.

## When to ask
- A request or an issue allows more than one reading, lacks acceptance criteria, or leaves scope, design or behavior open.
- The issue or PR text, its comments and the code disagree.
- A choice is the user's to make (which issue, what depth, what to remove, a new option or API).
- A subagent or Herdr agent reports a question (`BLOCKED`, or an open decision in its report). It cannot ask the user itself, so the main agent does.

## How
1. Use the harness's own question tool when it has one (`AskUserQuestion` in Claude Code, `ask_question` in Antigravity, `request_user_input` in Codex), otherwise plain text.
2. Gather every open question and ask once, in one call with several questions. Name what each is about.
3. Give the options with a recommended one first, marked as recommended.
4. Wait for the answer. Keep going only with the parts that have nothing open.

## When to decide alone
Only when the user said so: "go with your recommendation", "you decide". That covers the questions they said it for. Pick the recommended option and say in the report which choices you made.
