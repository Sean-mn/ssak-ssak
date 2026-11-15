#!/usr/bin/env bash
# Post replies in review threads of my own PR <n>: the only way ssak-respond writes to GitHub.
# Usage: post-replies.sh <pr#> <comment id>:<body file>...
#   <comment id> is the id review-threads.sh prints for a thread; <body file> holds the reply text.
# Refuses everything (exit 2) when the PR is not open or not mine, an id is not an unresolved thread of this PR,
# a body file is empty, or a reply names a local commit that is not on the PR yet (push first).
# A thread whose last comment is already mine is skipped. Never pushes and never resolves a thread.
# Output: "replied <comment id> <reply url>" or "skip <comment id>: you already replied last" per reply.
# Exit 3: GitHub rejected a reply; its message goes to stderr and the replies after it are not posted.
# Requires: bash, git, gh signed in (gh auth login), run inside a clone of the PR's repo. No jq: JSON goes through gh --jq.
set -euo pipefail
. "$(dirname "$0")/common.sh"

n=${1:-}
[[ "$n" =~ ^[1-9][0-9]*$ ]] && [ $# -ge 2 ] || { echo "usage: $0 <pr#> <comment id>:<body file>..." >&2; exit 2; }
shift
for a in "$@"; do
  [[ "$a" =~ ^[1-9][0-9]*:.+$ ]] && [ -s "${a#*:}" ] ||
    { echo "refused: $a is not <comment id>:<non-empty body file>" >&2; exit 2; }
done

targets=$(gh api graphql -F owner='{owner}' -F name='{repo}' -F n="$n" -f query="$THREAD_QUERY" --jq "$TARGETS_JQ")
read -r _ state mine head <<<"$(sed -n 1p <<<"$targets")"
[ "$state" = OPEN ] || { echo "refused: PR #$n is ${state:-not found}, not open" >&2; exit 2; }
[ "$mine" = mine ] || { echo "refused: PR #$n is not yours; ssak-respond answers reviews of your own PRs" >&2; exit 2; }

# A reply that says "fixed in <sha>" must point at a commit the reviewer can see
on_pr() {
  if ! git cat-file -e "$head^{commit}" 2>/dev/null; then
    GIT_TERMINAL_PROMPT=0 git fetch -q "$(gh repo view --json url -q .url)" "pull/$n/head" 2>/dev/null || true
  fi
  git merge-base --is-ancestor "$1" "$head" 2>/dev/null
}

for a in "$@"; do
  id=${a%%:*}; file=${a#*:}
  status=$(sed -n "s/^t $id //p" <<<"$targets" | head -1)
  case $status in
    open | answered) ;;
    resolved) echo "refused: thread $id is resolved" >&2; exit 2 ;;
    *) echo "refused: $id is not a review thread of PR #$n" >&2; exit 2 ;;
  esac
  for word in $(grep -oE '[0-9a-f]{7,40}' "$file" | sort -u); do
    commit=$(git rev-parse -q --verify "$word^{commit}" 2>/dev/null) || continue
    on_pr "$commit" || { echo "refused: the reply to $id names $word, which is not on PR #$n yet; push first" >&2; exit 2; }
  done
done

for a in "$@"; do
  id=${a%%:*}; file=${a#*:}
  if grep -qx "t $id answered" <<<"$targets"; then echo "skip $id: you already replied last"; continue; fi
  # The body goes in through stdin, not as an argument: Git Bash on Windows rewrites backslashes and paths in arguments
  if ! out=$(gh api "repos/{owner}/{repo}/pulls/$n/comments/$id/replies" -X POST -F body=@- --jq .html_url <"$file" 2>&1); then
    echo "reply to $id failed: $out" >&2
    exit 3
  fi
  echo "replied $id $out"
done
