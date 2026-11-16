# Agent model

Shared by every skill that starts subagents or Herdr agents. One rule for every agent:
worker, verifier, reviewer, refuter and Herdr panes. The scout has its own rule below.

## The rule
1. Every agent file says `model: inherit`. Pass no model to the subagent tool, so the agent runs on this session's model.
2. Exception, a session model above Opus (Fable, Mythos, or any other model ranked above Opus): before the first agent starts, ask the user once, as in `asking-the-user.md`, which model the agents run on:
   - Opus 5.5 (recommended): pass `opus` to the subagent tool, or `claude-opus-5-5` to a Herdr pane.
   - The session model: pass no model, or this session's full model ID to a Herdr pane.

   The answer covers every agent in this run. When the user said to go with your recommendation, or the harness has no way to ask, use Opus 5.5.
3. A model the user gave in the command (`--herdr <model>`, `/ssak-orchestrate <model>`) is used as given, with no question.
4. When the subagent tool has no model option, skip this: agents run on the session model. Say so in one line if the session model is above Opus.
5. Herdr panes always need a model (`--model`), so they get this session's full model ID (e.g. `claude-opus-5-5`), or the answer from step 2.

## The scout
`ssak-scout` runs on Sonnet 5.5, whatever the session model: pass `sonnet` to the subagent tool. Its agent file still says `model: inherit`.
- Why: the scout only finds code. It does not write or judge code, and the worker checks its map.
- The question in step 2 and its answer do not cover the scout.
- When the subagent tool has no model option, or the harness has no Sonnet (Codex, Antigravity), the scout runs on the session model.

For every other agent, never pick a weaker model to save time or cost; set depth with effort instead.
