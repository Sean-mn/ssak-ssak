# Contribution rules checklist

Fill this from the `guidelines.sh` output and the issue itself. Quote the file and line that a rule comes from. A rule you did not find is "not found", never a guess.

## Rules to extract
| Rule | Look for | What it changes |
|---|---|---|
| AI policy | "AI", "LLM", "generated", "Copilot", "ChatGPT", "Claude", "machine", "bot" in any rule file | **Banned** → stop. **Disclosure required** → follow its exact form (PR body note, label, commit trailer). |
| Claiming | "comment before", "ask to be assigned", "wait for", "approved", "triage", "accepted" | Required and not yet done → stop; the user must do it themselves. |
| Target branch | "target", "base branch", "against `develop`" | Pass it as `[base-branch]` to `setup-fork.sh`. |
| CLA | "CLA", "Contributor License Agreement", `CLA.md`, cla-assistant | Tell the user to sign it. Never sign for them. |
| DCO | "DCO", "Signed-off-by", `dco.yml` | Commit with `git commit -s`. |
| Commit format | Conventional Commits, `commitlint` config, examples in CONTRIBUTING | Follow it for every commit. |
| PR title format | "PR title", "prefix", scope examples | Follow it for the PR title. |
| Changelog | `.changeset/` note, "changeset", "CHANGELOG", "release notes" | Add the entry the repo asks for. |
| Dev commands | setup, test, lint, format, build commands | Run exactly these, not guessed ones. |
| Tests and docs | "add tests", "update docs" | Include them in the change. |
| PR scope | "one change per PR", "small PRs", "no unrelated changes" | Keep the diff to the issue. |
| PR template | `PULL_REQUEST_TEMPLATE*` | Fill every section; keep its checkboxes. |

## Stop conditions (issue status)
Stop and tell the user why, with the evidence line, when any of these hold:
- The issue is closed.
- Someone other than the user is assigned.
- A PR by someone else is linked to the issue and is open or merged: by closing keyword (`closes`), by the Development sidebar (`linked`), or pasted in a comment ("PRs linked in comments").
- An open PR by someone else in the same repo mentions the issue (`mentions`). A mention from another repo, or a closed PR, is only a hint.
- Someone else's comment appears under "claim comments" and no maintainer declined it since. The claim detector matches phrases like "I'll take this" or "working on it"; read the comments yourself too, since it misses other wording.
- Labels say it is not ready or not wanted: e.g. `needs triage`, `needs discussion`, `blocked`, `wontfix`, `duplicate`, `invalid`, `question`.

When the evidence is ambiguous (an old claim with no activity for months, an abandoned draft PR), do not decide alone: show it in the pre-flight summary and let the user choose.
