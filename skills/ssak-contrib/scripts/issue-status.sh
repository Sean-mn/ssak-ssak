#!/usr/bin/env bash
# Print what decides whether <owner/repo>#<issue> is free to take: state, assignees, labels,
# PRs that reference it, and the last 10 comments.
set -euo pipefail

repo=${1:-}; n=${2:-}
[[ "$repo" =~ ^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$ && "$n" =~ ^[1-9][0-9]*$ ]] || { echo "usage: $0 <owner/repo> <issue#>" >&2; exit 2; }

echo "me: $(gh api user -q .login)"
gh issue view "$n" -R "$repo" --json title,url,state,stateReason,assignees,labels --jq '
  "issue: \(.title)\nurl: \(.url)\nstate: \(.state) \(.stateReason // "")",
  "assignees: \([.assignees[].login] | join(", ") | if . == "" then "none" else . end)",
  "labels: \([.labels[].name] | join(", ") | if . == "" then "none" else . end)"'

echo "referencing PRs:"
prs=$(gh api "repos/$repo/issues/$n/timeline" --paginate --jq '
  .[] | select(.event == "cross-referenced" and .source.issue.pull_request != null) | .source.issue |
  "  \(.repository.full_name // "")#\(.number) \(.state)\(if .pull_request.merged_at then " merged" else "" end) by \(.user.login): \(.title)"')
echo "${prs:-  none}"

echo "last comments:"
comments=$(gh issue view "$n" -R "$repo" --json comments --jq '
  .comments[-10:][] | "  \(.createdAt[:10]) \(.author.login): \(.body | gsub("\\s+"; " ") | .[:200])"')
echo "${comments:-  none}"
