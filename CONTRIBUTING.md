# Contributing

## Before you file a bug...

- Is it a question? Open an issue with the `question` label.
- Did you search open and closed [issues](https://github.com/Sean-mn/ssak-ssak/issues?q=is%3Aissue) for a duplicate?
- Did you include the skill and its arguments, Claude Code or Codex, your OS, and what happened versus what you expected?

## Before you submit a PR...

- Is there an issue for it? If not, open one first.
- Is the title `<type>: <what changed>`, with type `feat`, `fix`, `docs`, `ci`, `test`, `refactor` or `chore`?
- Did you leave the version alone? Only a `release vX.Y.Z: ...` PR changes it.
- Did you run `python .github/check.py` and `bash tests/run.sh`?
- New or changed command? Did you update the skills table in both `README.md` and `README.ko.md`?

## Looking for something to work on?

Look at the [`good first issue`](https://github.com/Sean-mn/ssak-ssak/labels/good%20first%20issue) and [`help wanted`](https://github.com/Sean-mn/ssak-ssak/labels/help%20wanted) issues.

## Working with an AI agent?

Point it at [`AGENTS.md`](AGENTS.md). It covers the working loop and the hard rules, and links to [`docs/`](docs/) for how the skills fit together, how to write them, and how to release.
