#!/usr/bin/env bash
# Print what decides whether <owner/repo>#<issue> is free to take: state, assignees, labels,
# linked PRs (closing keywords, manual Development links, mentions), PRs linked in comments,
# comments that look like a claim, and the last 10 comments.
set -euo pipefail
. "$(dirname "$0")/../../ssak-issue/scripts/common.sh"

repo=${1:-}; n=${2:-}
valid_repo "$repo" && [[ "$n" =~ ^[1-9][0-9]*$ ]] || { echo "usage: $0 <owner/repo> <issue#>" >&2; exit 2; }

echo "me: $(gh api user -q .login)"

out=$(gh api graphql -f owner="${repo%%/*}" -f name="${repo#*/}" -F n="$n" \
  -f query="query(\$owner: String!, \$name: String!, \$n: Int!) { repository(owner: \$owner, name: \$name) { issue(number: \$n) { $ISSUE_FIELDS } } } $PR_FRAGMENT" \
  --jq "$JQ_DEFS"'
  .data.repository.issue | . as $i | linked as $l |
  "issue: \(.title)\nurl: \(.url)\nstate: \(.state) \(.stateReason // "")",
  "assignees: \([.assignees.nodes[].login] | join(", ") | if . == "" then "none" else . end)",
  "labels: \([.labels.nodes[].name] | join(", ") | if . == "" then "none" else . end)",
  "linked PRs (closes = closing keyword, linked/unlinked = Development sidebar, mentions = PR references the issue):",
  (if ($l | length) == 0 then "  none" else ($l[] | "  \(.s) [\(.via)]") end),
  "claim comments:",
  (claims | if length == 0 then "  none" else .[] | "  \(.)" end),
  "last comments (\([.comments.totalCount, 10] | min) of \(.comments.totalCount)):",
  (.comments.nodes[-10:] | if length == 0 then "  none" else .[] | "  \(.createdAt[:10]) \(.author.login // "ghost"): \(.body | oneline(200))" end),
  "@@refs " + ([ (.comments.nodes[].body | scan("github[.]com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)/pull/([0-9]+)") | "\(.[0])#\(.[1])"),
                 (.comments.nodes[].body | scan("(?:^|[^A-Za-z0-9_/&])#([0-9]+)") | "'"$repo"'#\(.[0])") ]
               - [$l[].s | split(" ")[0]] - ["'"$repo"'#\($i.number)"] | unique | .[:20] | join(" "))')

grep -v '^@@refs' <<<"$out"

# PRs pasted into comments leave no event on the issue itself, so resolve each #N / pull URL found in comments
echo "PRs linked in comments:"
found=0
for ref in $(sed -n 's/^@@refs //p' <<<"$out"); do
  line=$(gh pr view "${ref#*#}" -R "${ref%#*}" --json state,author -q "\"  $ref \(.state) by \(.author.login)\"" 2>/dev/null) || continue
  echo "$line"; found=1
done
[ "$found" = 1 ] || echo "  none"
