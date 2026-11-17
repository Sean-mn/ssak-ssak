#!/usr/bin/env bash
# Post reviews on PR <n>, one per JSON payload file, in order: the only way ssak-review writes to GitHub.
# Each payload is one review: a single inline comment, or a body with no comments.
# Checks every payload before posting any. Refuses (exit 2) unless "event" is COMMENT, "commit_id" is the PR head,
# a payload has at most one comment, on side RIGHT and on a line in the PR diff, and I have not reviewed that head yet.
# Output: one review URL per line. Exit 3: GitHub rejected one; the ones before it stay posted, the rest are not posted.
# Requires: bash, gh signed in (gh auth login), run inside a clone of the PR's repo. No jq: JSON goes through gh --jq.
set -euo pipefail
. "$(dirname "$0")/common.sh"

n=${1:-}
[[ "$n" =~ ^[1-9][0-9]*$ ]] && [ $# -ge 2 ] || { echo "usage: $0 <pr#> <payload.json>..." >&2; exit 2; }
shift

# Unescaped occurrences of key $2 in file $1, with their value. Keys inside comment bodies are escaped (\"event\").
# shortcut: grep, not a JSON parser (no jq here); fine for the payloads this skill writes, use a parser if payloads grow
keys() { grep -oE '(^|[^\\])"'"$2"'"[[:space:]]*:[[:space:]]*("[^"]*"|[0-9]+)' "$1" || true; }
value() { keys "$1" "$2" | sed -E 's/.*:[[:space:]]*"?([^"]*)"?$/\1/'; }

head=$(gh pr view "$n" --json headRefOid -q .headRefOid)
hunks=$(gh api "repos/{owner}/{repo}/pulls/$n/files" --paginate --jq "$HUNKS_JQ")

for p in "$@"; do
  [ -f "$p" ] || { echo "refused: no such payload: $p" >&2; exit 2; }
  event=$(value "$p" event)
  [ "$event" = COMMENT ] || { echo "refused: $p: event must be exactly one \"COMMENT\", got: ${event:-none}" >&2; exit 2; }
  [ "$(value "$p" commit_id)" = "$head" ] || { echo "refused: $p: commit_id is not the PR head $head" >&2; exit 2; }
  count=$(keys "$p" path | grep -c . || true)
  if [ "$count" -eq 0 ]; then
    keys "$p" body | grep -qE ':[[:space:]]*"[^"]' || { echo "refused: $p: no comment and no body" >&2; exit 2; }
    continue
  fi
  [ "$count" -eq 1 ] || { echo "refused: $p: $count comments, post one per payload" >&2; exit 2; }
  path=$(value "$p" path); line=$(value "$p" line)
  [ "$(value "$p" side)" = RIGHT ] || { echo "refused: $p: side must be \"RIGHT\"" >&2; exit 2; }
  printf '%s\n' "$hunks" | awk -F'\t' -v f="$path" -v l="${line:-0}" '$1 == f && l >= $2 && l <= $3 { ok = 1 } END { exit !ok }' ||
    { echo "refused: $p: $path:${line:-?} is not on a line in the PR diff; put it in the body" >&2; exit 2; }
done

me=$(gh api user -q .login)
done_url=$(gh api "repos/{owner}/{repo}/pulls/$n/reviews" --paginate \
  --jq ".[] | select(.user.login == \"$me\" and .commit_id == \"$head\") | .html_url")
[ -z "$done_url" ] || { echo "refused: you already reviewed this head: $done_url" >&2; exit 2; }

i=0
for p in "$@"; do
  if ! out=$(gh api "repos/{owner}/{repo}/pulls/$n/reviews" -X POST --input "$p" --jq .html_url 2>&1); then
    echo "$out" >&2
    echo "posted $i of $#; not posted: $p and the ones after it" >&2
    exit 3
  fi
  echo "$out"
  i=$((i + 1))
done
