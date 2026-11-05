# Authoring skills, agents and scripts

The reader of a skill is a model following it step by step. Write so that it can act
without judgment calls: exact commands, explicit stop conditions, fixed output formats.

## Skills

- Frontmatter: `name` (matches the folder), `description`, `argument-hint` (quoted if
  it starts with `[`), and a `# for:` comment naming the models it was checked on.
  check.py validates all of this.
- The `description` decides when the skill fires. It says what the skill does and ends
  with `Use for "..."` examples. After changing it, run the trigger evals:
  `claude plugin eval . --runs 1 --ablation none --no-publish`.
- Start the body with `Arguments: $ARGUMENTS` and a list of every script, reference and
  agent the skill uses, with one line on what each does and prints. Paths are relative
  to the skill folder, and check.py fails on a missing one.
- Number the steps. Each step that can fail says what to tell the user and that the
  skill stops.
- Never pick a value the user must choose (effort, which issues, what to remove). Show
  the usage and stop instead.
- Ask before anything outward-facing or destructive, and wait for the answer.
- Long multi-phase skills get a checklist near the top that the agent ticks off.
- End with a `## Rules` section of hard limits: what the skill never does.
- Put long templates (briefs, reports, comment formats) in `references/` so they load
  only when needed.
- The skills table in both `README.md` and `README.ko.md` has a row per command.

## Agents

- Frontmatter: `name`, `description`, `model`, `effort`, `tools`. Pin `effort` so a
  max-effort session does not fan out max-effort agents. Checking agents get only
  `Read, Grep, Glob, Bash`.
- `omitClaudeMd: true` for agents that need only their brief or read the repo's rule
  files themselves (reviewer, refuter).
- Sections: what the brief gives you, `## Do not`, `## Steps`, a verdict or result
  rule, and `## Report format` as a fenced block.
- Reports are in English. The main agent translates for the user.
- When a skill's brief and an agent's instructions describe the same thing, change
  both.

## Scripts

- Header comment: one line on what it does, the usage line, the output format, exit
  codes other than 0 and 1, and a `# Requires:` line (e.g. `bash, git, gh signed in`).
- `set -euo pipefail`. Print machine-readable lines (`key value`) that the skill
  parses, and errors to stderr.
- Refuse unsafe input with exit 2 and a clear message. That is how the skills enforce
  safety, so do not rely on the agent passing good input.
- Run shared helpers next to the script as `"$(dirname "$0")/common.sh"`; check.py
  checks these paths.
- Add a test in `tests/run.sh` for every new script or behavior. Tests use a throwaway
  git repo with a local bare origin and a `gh` stub, so they run offline.

Scripts run on all three of CI's test systems. Keep in mind:

- **bash 3.2 on macOS** (CI uses the stock `/bin/bash`): no associative arrays, no
  `mapfile`/`readarray`, no `${x,,}`. An empty array under `set -u` needs
  `${arr[@]+"${arr[@]}"}`.
- **Git Bash on Windows**: it turns `\\` into `\` when calling `gh.exe`, so jq
  programs passed to `gh --jq` use `[.]`, `[0-9]`, `[[:space:]]` instead of
  backslashes (see `common.sh`). Paths may contain spaces, regex characters and
  non-ASCII: `cleanup.sh` once broke on `(x86)`, and the tests use `a (x86) 문서/repo`.
- **No jq dependency**: JSON goes through `gh --jq`.
- `.sh` files are LF (`.gitattributes`); keep them so on Windows checkouts.

## Evals

`evals/<case>/case.yaml` checks whether a prompt fires the right skill. Add a positive
case for a new skill and a negative case (`max: 0`) when a nearby prompt must not fire
any ssak skill, e.g. a local test failure is not a CI failure.
