# shellcheck shell=bash disable=SC2034  # sourced: the variables are used by the scripts that source this file
# Shared issue helpers for ssak-issue and ssak-contrib scripts (sourced, not run).
# Requires: bash, gh signed in (gh auth login). No jq: JSON goes through gh --jq.

valid_repo() { [[ "$1" =~ ^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$ ]]; }

# GraphQL fields that tell whether an issue is taken.
# shortcut: only the last 100 comments and timeline events are read; paginate if a busy issue ever needs more.
ISSUE_FIELDS='
  number title url state stateReason updatedAt
  assignees(first: 10) { nodes { login } }
  labels(first: 30) { nodes { name } }
  closedByPullRequestsReferences(first: 20, includeClosedPrs: true) { nodes { ...P } }
  timelineItems(last: 100, itemTypes: [CROSS_REFERENCED_EVENT, CONNECTED_EVENT, DISCONNECTED_EVENT]) { nodes { __typename
    ... on CrossReferencedEvent { source { ...P } }
    ... on ConnectedEvent { subject { ...P } }
    ... on DisconnectedEvent { subject { ...P } } } }
  comments(last: 100) { totalCount nodes { createdAt author { login } body } }'
PR_FRAGMENT='fragment P on PullRequest { number url state author { login } repository { nameWithOwner } }'

# jq (gojq) helpers over an issue object with ISSUE_FIELDS.
# No backslashes in jq programs: Git Bash on Windows turns "\\" into "\" when calling gh.exe. Use [.] [0-9] [[:space:]] instead.
JQ_DEFS='
def pr: "\(.repository.nameWithOwner)#\(.number) \(.state) by \(.author.login // "ghost")";
def linked:
  ( [.closedByPullRequestsReferences.nodes[] | {k: .url, s: pr, state, via: "closes"}]
  + [.timelineItems.nodes[]
      | (if .__typename == "CrossReferencedEvent" then {p: .source, via: "mentions"}
         elif .__typename == "ConnectedEvent" then {p: .subject, via: "linked"}
         else {p: .subject, via: "unlinked"} end)
      | select(.p.number != null) | .via as $v | .p | {k: .url, s: pr, state, via: $v}] )
  | group_by(.k) | map({s: .[0].s, state: .[0].state, via: ([.[].via] | unique | join(", "))});
def claim_re: "(?m)(^|[^a-z])(i.?ll|i will|i.?d like to|i want to|can i|could i|may i|let me|i.?m going to)[^a-z].{0,30}(take|work|pick|tackle|handle|fix)|(^|[^a-z])working on (this|it)([^a-z]|$)|(^|[^a-z])assign (this |it )?to me([^a-z]|$)|^[[:space:]]*/(assign|take)([^a-z]|$)";
def oneline(n): gsub("[[:space:]]+"; " ") | .[:n];
def claims: [.comments.nodes[] | select(.body | test(claim_re; "i"))
  | "\(.createdAt[:10]) \(.author.login // "ghost"): \(.body | oneline(160))"];
'
