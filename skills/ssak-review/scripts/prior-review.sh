#!/usr/bin/env bash
# Print what I already posted on PR <n>, so a second review does not post the same finding twice. Read only.
# Usage: prior-review.sh <pr#>
# Output: "none", or "reviewed <commit sha> <review url>" for my last review, then one line per review thread I started:
#   "comment <open|resolved> <current|outdated> <path>:<line> <comment url> | <start of the comment>"
#   outdated = the commented lines changed since the comment. <line> is the line at the head, or where it was.
# shortcut: only the last 100 reviews and review threads are read; paginate if a PR ever needs more.
# Requires: bash, gh signed in (gh auth login), run inside a clone of the PR's repo. No jq: JSON goes through gh --jq.
set -euo pipefail
. "$(dirname "$0")/common.sh"

n=${1:-}
[[ "$n" =~ ^[1-9][0-9]*$ ]] || { echo "usage: $0 <pr#>" >&2; exit 2; }

gh api graphql -F owner='{owner}' -F name='{repo}' -F n="$n" -f query='
  query($owner: String!, $name: String!, $n: Int!) { viewer { login } repository(owner: $owner, name: $name) {
    pullRequest(number: $n) {
      reviews(last: 100) { nodes { state url author { login } commit { oid } } }
      reviewThreads(last: 100) { nodes { isResolved isOutdated path line originalLine
        comments(first: 1) { nodes { url body author { login } } } } } } } }' --jq "$PRIOR_JQ"
