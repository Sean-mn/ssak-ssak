#!/usr/bin/env bash
# Post one review on PR <n> from a JSON payload file: the only way ssak-review writes to GitHub.
# Refuses (exit 2) unless "event" is COMMENT and "commit_id" is the PR head, and when I already reviewed that head.
# Output: the review URL. Exit 3: GitHub rejected the payload; its message goes to stderr.
# Requires: bash, gh signed in (gh auth login), run inside a clone of the PR's repo. No jq: JSON goes through gh --jq.
set -euo pipefail

n=${1:-}; payload=${2:-}
[[ "$n" =~ ^[1-9][0-9]*$ ]] && [ -f "$payload" ] || { echo "usage: $0 <pr#> <payload.json>" >&2; exit 2; }

# Top-level value of key $1. Keys inside comment bodies are escaped (\"event\"), so they do not match.
# shortcut: grep, not a JSON parser (no jq here); fine for the payload this skill writes, use a parser if payloads grow
value() { grep -oE '(^|[^\\])"'"$1"'"[[:space:]]*:[[:space:]]*"[^"]*"' "$payload" | sed -E 's/.*"([^"]*)"$/\1/'; }

event=$(value event)
[ "$event" = COMMENT ] || { echo "refused: event must be exactly one \"COMMENT\", got: ${event:-none}" >&2; exit 2; }

head=$(gh pr view "$n" --json headRefOid -q .headRefOid)
[ "$(value commit_id)" = "$head" ] || { echo "refused: commit_id is not the PR head $head" >&2; exit 2; }

me=$(gh api user -q .login)
done_url=$(gh api "repos/{owner}/{repo}/pulls/$n/reviews" --paginate \
  --jq ".[] | select(.user.login == \"$me\" and .commit_id == \"$head\") | .html_url")
[ -z "$done_url" ] || { echo "refused: you already reviewed this head: $done_url" >&2; exit 2; }

if ! out=$(gh api "repos/{owner}/{repo}/pulls/$n/reviews" -X POST --input "$payload" --jq .html_url 2>&1); then
  echo "$out" >&2
  exit 3
fi
echo "$out"
