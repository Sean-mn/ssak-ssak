#!/usr/bin/env bash
# Print the review comments waiting on PR <n>. Read only.
# Usage: review-threads.sh <pr#>
# Output:
#   "pr <state> <mine|by <author>> head <sha> <url>"
#   "threads: <n> open, <n> answered, <n> resolved"   answered = my comment is the last one; it waits on the reviewer
#   per unresolved thread: "===== thread <comment id> <open|answered> <current|outdated> <path>:<line> <url>",
#     then its comments as "  <author> <date>: <body>" (later body lines are indented four spaces)
#   per review body by someone else: "===== review <author> <state> <url>", then the body
#   <comment id> is what post-replies.sh takes. outdated = the commented lines changed since the comment.
# Requires: bash, gh signed in (gh auth login), run inside a clone of the PR's repo. No jq: JSON goes through gh --jq.
set -euo pipefail
. "$(dirname "$0")/common.sh"

n=${1:-}
[[ "$n" =~ ^[1-9][0-9]*$ ]] || { echo "usage: $0 <pr#>" >&2; exit 2; }

gh api graphql -F owner='{owner}' -F name='{repo}' -F n="$n" -f query="$THREAD_QUERY" --jq "$THREADS_JQ"
