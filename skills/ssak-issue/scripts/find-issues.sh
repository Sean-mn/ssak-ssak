#!/usr/bin/env bash
# List open issues of <owner/repo> worth picking up, grouped as FREE / CLAIMED / NOT READY / TAKEN.
# --beginner: only unassigned issues with beginner labels (good first issue, help wanted, ...).
# TAKEN = an open or merged linked PR, or assigned to someone else. NOT READY = labels like blocked or needs-triage.
# CLAIMED = a comment that looks like a claim.
# PR links pasted in comments are not checked here; check the picked issue in full before working on it.
set -euo pipefail
. "$(dirname "$0")/common.sh"

repo=${1:-}; mode=${2:-}
valid_repo "$repo" && { [ -z "$mode" ] || [ "$mode" = --beginner ]; } || { echo "usage: $0 <owner/repo> [--beginner]" >&2; exit 2; }

me=$(gh api user -q .login)
q="repo:$repo is:issue is:open sort:updated-desc"

if [ "$mode" = --beginner ]; then
  labels=$(gh label list -R "$repo" -L 500 --json name -q '.[].name' |
    grep -iE '^(good[ _-]?first[ _-]?(issue|bug|contribution)s?|help[ _-]?wanted|beginner([ _-]?friendly)?|first[ _-]?timers?([ _-]?only)?|easy|starter)$' || true)
  [ -n "$labels" ] || { echo "no beginner labels (good first issue, help wanted, ...) in $repo"; exit 0; }
  q="$q no:assignee label:$(while read -r l; do printf '"%s",' "$l"; done <<<"$labels" | sed 's/,$//')"
fi

echo "query: $q"
gh api graphql -f q="$q" \
  -f query="query(\$q: String!) { search(type: ISSUE, query: \$q, first: 30) { issueCount nodes { ... on Issue { $ISSUE_FIELDS } } } } $PR_FRAGMENT" \
  --jq "$JQ_DEFS"'
  .data.search as $s |
  [ $s.nodes[] | linked as $l | [.assignees.nodes[].login] as $a | claims as $c |
    { line: "#\(.number) \(.title | oneline(90))\([.labels.nodes[].name] | if length > 0 then " [\(join(", "))]" else "" end) · updated \(.updatedAt[:10]) · \(.comments.totalCount) comments",
      mine: ($a | index("'"$me"'") != null),
      # a closing or Development link that is open or merged, or an open same-repo PR that mentions the issue
      why: ( [$l[] | select((.via | test("(^|, )(closes|linked)(,|$)")) and .state != "CLOSED"
                            or .state == "OPEN" and (.s | startswith("'"$repo"'#"))) | "PR \(.s) [\(.via)]"]
           + [$a[] | select(. != "'"$me"'") | "assigned: \(.)"] ),
      claim: $c,
      notready: [.labels.nodes[].name | select(test("^(blocked|on[ _-]?hold|needs?[ _-]?(triage|discussion|design|info|decision)|wontfix|won.?t fix|duplicate|invalid|question)$"; "i"))] }
    | .group = (if (.why | length) > 0 then "TAKEN" elif (.notready | length) > 0 then "NOT READY"
                elif (.claim | length) > 0 then "CLAIMED" else "FREE" end) ] as $all |
  def section(g; title; detail):
    title, ([$all[] | select(.group == g)] | sort_by(.mine | not) |
      if length == 0 then "  none" else .[] | "  \(.line)\(if .mine then " · assigned to you" else "" end)", (detail | select(. != null) | "    \(.)") end);
  "matched \($s.issueCount), showing \($all | length)",
  section("FREE"; "FREE:"; null),
  section("CLAIMED"; "CLAIMED (read the claim before taking):"; "claim: \(.claim[-1])"),
  section("NOT READY"; "NOT READY (labels say wait):"; .notready | join(", ")),
  section("TAKEN"; "TAKEN (skip):"; .why | join(" / "))'
