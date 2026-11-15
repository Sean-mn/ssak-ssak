# shellcheck shell=bash disable=SC2034  # sourced: the variable is used by prior-review.sh
# Shared jq for the ssak-review scripts (sourced, not run).
# No "\\" in jq programs: Git Bash on Windows turns it into "\" when calling gh.exe. Use [[:space:]] and the like.

# Over the prior-review.sh query result: my last submitted review, then one line per review thread I started.
PRIOR_JQ='
def oneline(n): gsub("[[:space:]]+"; " ") | .[:n];
.data | .viewer.login as $me | .repository.pullRequest as $p |
[$p.reviews.nodes[] | select(.author.login == $me and .state != "PENDING")] as $r |
[$p.reviewThreads.nodes[] | select(.comments.nodes[0].author.login == $me)] as $t |
if ($r | length) == 0 and ($t | length) == 0 then "none" else
  ($r[-1] | select(.) | "reviewed \(.commit.oid // "unknown") \(.url)"),
  ($t[] | "comment \(if .isResolved then "resolved" else "open" end) \(if .isOutdated then "outdated" else "current" end) \(.path):\(.line // .originalLine // 0) \(.comments.nodes[0].url) | \(.comments.nodes[0].body | oneline(200))")
end'
