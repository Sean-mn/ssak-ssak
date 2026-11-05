# CLAUDE.md

@AGENTS.md

## Claude Code specifics

- Use targeted search (Grep/Glob) and read only the files a task needs. Start from the
  skill's `SKILL.md`; its first list names every script, reference and agent it uses.
- To try a skill change, load this checkout as a plugin
  (`claude --plugin-dir .`) and run the skill on a real repo. Say in the PR what you
  ran and the result.
- The ssak skills create `.claude/worktrees/` and `ssak/*` branches. When testing them
  here, clean up with `/ssak-clean-up` afterwards.
- For web lookups, prefer official documentation (Claude Code docs, Codex docs,
  GitHub Docs, GitHub CLI manual).
- Long tasks: one PR at a time; report which PRs merged and what remains, including any
  check that failed or was skipped.
- Never add `Co-Authored-By` or other attribution trailers to commits or PRs.
