# shellcheck shell=bash disable=SC2034  # sourced: the variables are used by the scripts that source this file
# Shared GraphQL and jq for the ssak-respond scripts (sourced, not run).
# No "\\" in jq programs: Git Bash on Windows turns it into "\" when calling gh.exe.

# The review threads and reviews of one pull request.
# shortcut: only the last 100 threads, the first 50 comments of each and the last 30 reviews are read; paginate if a PR needs more.
THREAD_QUERY='
  query($owner: String!, $name: String!, $n: Int!) { viewer { login } repository(owner: $owner, name: $name) {
    pullRequest(number: $n) { state url headRefOid author { login }
      reviewThreads(last: 100) { nodes { isResolved isOutdated path line originalLine
        all: comments(first: 50) { nodes { databaseId url createdAt author { login } body } }
        last: comments(last: 1) { nodes { author { login } } } } }
      reviews(last: 30) { nodes { state url submittedAt author { login } body } } } } }'

# open = the last comment is someone else's; answered = mine, so it waits on the reviewer.
JQ_DEFS='
def who: .author.login // "ghost";
def status($me): if .isResolved then "resolved" elif (.last.nodes[0] | who) == $me then "answered" else "open" end;
def indent: gsub("\r"; "") | gsub("\n"; "\n    ");
'

# review-threads.sh: a summary, then every unresolved thread with its comments, then review bodies by other people.
THREADS_JQ="$JQ_DEFS"'
.data | .viewer.login as $me | .repository.pullRequest as $p |
[$p.reviewThreads.nodes[] | . + {s: status($me)}] as $t |
"pr \($p.state) \(if ($p | who) == $me then "mine" else "by \($p | who)" end) head \($p.headRefOid) \($p.url)",
"threads: \([$t[] | select(.s == "open")] | length) open, \([$t[] | select(.s == "answered")] | length) answered, \([$t[] | select(.s == "resolved")] | length) resolved",
($t[] | select(.s != "resolved") |
  "===== thread \(.all.nodes[0].databaseId) \(.s) \(if .isOutdated then "outdated" else "current" end) \(.path):\(.line // .originalLine // 0) \(.all.nodes[0].url)",
  (.all.nodes[] | "  \(who) \(.createdAt[:10]): \(.body | indent)")),
($p.reviews.nodes[] | select(who != $me and .state != "PENDING" and (.body | length) > 0) |
  "===== review \(who) \(.state) \(.url)", "  \(.body | indent)")'

# post-replies.sh: the PR line, then "t <comment id> <open|answered|resolved>" per thread.
TARGETS_JQ="$JQ_DEFS"'
.data | .viewer.login as $me | .repository.pullRequest as $p |
"pr \($p.state) \(if ($p | who) == $me then "mine" else "other" end) \($p.headRefOid)",
($p.reviewThreads.nodes[] | "t \(.all.nodes[0].databaseId) \(status($me))")'
