#!/usr/bin/env bash
# Tests for the skill scripts in a throwaway git repo (local bare origin, no network).
# The tests marked (gh jq) run through gh's own jq and are skipped when gh is not logged in.
#   bash tests/run.sh
set -uo pipefail

skills="$(cd "$(dirname "$0")/.." && pwd)/skills"
fails=0
check() {  # check <name> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "ok   $1"; else
    echo "FAIL $1"; printf '  expected: %s\n  actual:   %s\n' "$2" "$3"; fails=$((fails + 1)); fi
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# Isolate from the user's git config (signing, hooks, default branch)
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$tmp/gitconfig"
printf '[user]\n\tname = t\n\temail = t@t\n[init]\n\tdefaultBranch = main\n' > "$GIT_CONFIG_GLOBAL"
# gh stub keeps tests offline: pr-worktree.sh gets the local origin as the PR's repo and STUB_PR as
# the PR's "<isCrossRepository> <author>" (I am "me"); cleanup.sh's PR lookup fails
mkdir "$tmp/bin" && cat > "$tmp/bin/gh" <<EOF
#!/bin/sh
case "\$1 \$2" in
  "repo view") echo "$tmp/origin.git" ;;
  "pr view") echo "\${STUB_PR:-false me}" ;;
  "api user") echo me ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$tmp/bin/gh"
offline() { PATH="$tmp/bin:$PATH" "$@"; }

# Regex characters and non-ASCII in the path: cleanup.sh once broke on "(x86)"
repo="$tmp/a (x86) 문서/repo"
git init -q --bare "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$repo" 2>/dev/null
cd "$repo" || exit 1
git commit -q --allow-empty -m init && git push -q origin main 2>/dev/null
git remote set-head origin -a >/dev/null
root=$(git rev-parse --show-toplevel)
wt="$root/.claude/worktrees"

echo "# base-branch.sh"
check "default branch" "origin/main" "$(bash "$skills/ssak-issue/scripts/base-branch.sh")"

echo "# make-worktrees.sh"
out=$(bash "$skills/ssak-issue/scripts/make-worktrees.sh" 3 2 3 2>&1)
check "sorted, deduped" "base origin/main
issue 2 ssak/issue-2 $wt/ssak-issue-2
issue 3 ssak/issue-3 $wt/ssak-issue-3" "$out"
check "rerun reuses" "$out" "$(bash "$skills/ssak-issue/scripts/make-worktrees.sh" 2 3 2>&1)"
check "excluded once" "1" "$(grep -cxF '.claude/worktrees/' "$(git rev-parse --git-common-dir)/info/exclude")"
check "main checkout clean" "" "$(git status --porcelain)"
bash "$skills/ssak-issue/scripts/make-worktrees.sh" abc >/dev/null 2>&1
check "rejects non-number" "2" "$?"

echo "# pr-worktree.sh"
review="$skills/ssak-review/scripts/pr-worktree.sh"
pr=$(git commit-tree -m pr "HEAD^{tree}")
git push -q origin "$pr:refs/pull/7/head" 2>/dev/null
check "checks out PR head" "$pr $wt/ssak-review-7
fork no me" "$(offline bash "$review" 7 2>&1)"
check "someone else's fork" "fork yes them" "$(STUB_PR='true them' offline bash "$review" 7 2>&1 | tail -1)"
check "my own fork" "fork no me" "$(STUB_PR='true me' offline bash "$review" 7 2>&1 | tail -1)"
pr=$(git commit-tree -p "$pr" -m pr2 "HEAD^{tree}")
git push -q origin "$pr:refs/pull/7/head" 2>/dev/null
offline bash "$review" 7 >/dev/null 2>&1
check "rerun moves to new head" "$pr" "$(git -C "$wt/ssak-review-7" rev-parse HEAD)"
check "main checkout still clean" "" "$(git status --porcelain)"
offline bash "$review" abc >/dev/null 2>&1
check "rejects non-number" "2" "$?"
pr8=$(git commit-tree -m pr8 "HEAD^{tree}")
git push -q origin "$pr8:refs/pull/8/head" 2>/dev/null
pr7=$(git commit-tree -p "$pr" -m pr3 "HEAD^{tree}")
git push -q origin "$pr7:refs/pull/7/head" 2>/dev/null
offline bash "$review" 7 >/dev/null 2>&1 & offline bash "$review" 8 >/dev/null 2>&1 & wait
check "parallel runs check out their own heads" "$pr7 $pr8" \
  "$(git -C "$wt/ssak-review-7" rev-parse HEAD) $(git -C "$wt/ssak-review-8" rev-parse HEAD)"
check "leaves no fetch refs behind" "" "$(git for-each-ref refs/ssak/)"
git worktree remove "$wt/ssak-review-8"

echo "# cleanup.sh"
cleanup="$skills/ssak-clean-up/scripts/cleanup.sh"
check "scan" "issue-2 SAFE wt=$wt/ssak-issue-2 branch=ssak/issue-2 | nothing to lose
issue-3 SAFE wt=$wt/ssak-issue-3 branch=ssak/issue-3 | nothing to lose
review-7 SAFE wt=$wt/ssak-review-7 branch=- | nothing to lose" "$(offline bash "$cleanup" scan)"

echo x > "$wt/ssak-issue-3/f"
check "dirty is risky" "issue-3 RISKY wt=$wt/ssak-issue-3 branch=ssak/issue-3 | uncommitted changes in worktree" \
  "$(offline bash "$cleanup" scan | grep '^issue-3')"
git -C "$wt/ssak-issue-3" add f && git -C "$wt/ssak-issue-3" commit -qm f
check "unpushed is risky" "issue-3 RISKY wt=$wt/ssak-issue-3 branch=ssak/issue-3 | 1 commit(s) not on any remote" \
  "$(offline bash "$cleanup" scan | grep '^issue-3')"

check "remove safe" "removed issue-2
removed review-7" "$(offline bash "$cleanup" remove issue-2 review-7)"
check "worktree and branch gone" "" "$(git branch --list ssak/issue-2; git worktree list | grep -E 'ssak-(issue-2|review-7)')"
check "risky needs --force" "skip (needs --force): issue-3 RISKY wt=$wt/ssak-issue-3 branch=ssak/issue-3 | 1 commit(s) not on any remote" \
  "$(offline bash "$cleanup" remove issue-3)"
check "keep-branch only checks worktree" "removed issue-3 worktree (kept branch)" \
  "$(offline bash "$cleanup" remove --keep-branch issue-3)"
check "kept branch still risky" "issue-3 RISKY wt=- branch=ssak/issue-3 | 1 commit(s) not on any remote" \
  "$(offline bash "$cleanup" scan)"
check "force removes" "removed issue-3" "$(offline bash "$cleanup" remove --force issue-3)"
check "nothing left" "nothing to clean" "$(offline bash "$cleanup" scan)"
check "ignores non-ssak ids" "skip main: not an ssak id" "$(offline bash "$cleanup" remove main)"
mkdir -p "$wt" && echo b > "$wt/ssak-issue-9.brief.md" && echo r > "$wt/ssak-issue-9.report.md" && echo x > "$wt/ssak-issue-9.notes.md"
check "scans leftover handoff files" "issue-9 SAFE wt=- branch=- | handoff files: brief, report" "$(offline bash "$cleanup" scan)"
check "keep-branch keeps handoff files" "skip issue-9: not found" "$(offline bash "$cleanup" remove --keep-branch issue-9)"
check "removes handoff files" "removed issue-9" "$(offline bash "$cleanup" remove issue-9)"
check "only the handoff files" "$wt/ssak-issue-9.notes.md" "$(ls "$wt"/ssak-issue-9.*)"
rm -f "$wt/ssak-issue-9.notes.md"
check "nothing left again" "nothing to clean" "$(offline bash "$cleanup" scan)"

echo "# make-worktrees.sh, project branch names"
out=$(bash "$skills/ssak-issue/scripts/make-worktrees.sh" 4:feat/4-x 2>&1)
check "named branch" "base origin/main
issue 4 feat/4-x $wt/ssak-issue-4" "$out"
check "rerun reports the worktree's branch" "$out" "$(bash "$skills/ssak-issue/scripts/make-worktrees.sh" 4 2>&1)"
bash "$skills/ssak-issue/scripts/make-worktrees.sh" 5:bad..name >/dev/null 2>&1
check "rejects bad branch name" "2" "$?"
check "keep-branch keeps named branch" "removed issue-4 worktree (kept branch)
feat/4-x" "$(offline bash "$cleanup" remove --keep-branch issue-4; git branch --list --format='%(refname:short)' feat/4-x)"
check "scans kept named branch" "issue-4 SAFE wt=- branch=feat/4-x | nothing to lose" "$(offline bash "$cleanup" scan)"
check "removes kept named branch" "removed issue-4" "$(offline bash "$cleanup" remove issue-4)"

echo "# base-branch.sh, develop-like"
git branch -q develop
check "develop with nothing new is skipped" "origin/main" "$(bash "$skills/ssak-issue/scripts/base-branch.sh")"
git branch -q -f develop "$(git commit-tree -p HEAD -m dev "HEAD^{tree}")"
check "local develop" "develop" "$(bash "$skills/ssak-issue/scripts/base-branch.sh")"
git push -q origin develop 2>/dev/null
check "remote develop first" "origin/develop" "$(bash "$skills/ssak-issue/scripts/base-branch.sh")"

echo "# release-notes.sh"
notes="$skills/../.github/release-notes.sh"
git tag v0.0.1
for m in "feat(x): add a" "fix: b" "docs: c"; do git commit -q --allow-empty -m "$m"; done
out=$(bash "$notes" v0.0.2)
check "grouped by type" "### Features
- add a
### Fixes
- b
### Other
- docs: c" "$(awk '/^## Update/ { exit } /^(###|-) /' <<<"$out" | sed -E 's/ \([0-9a-f]+\)$//')"
check "compare link" "**Full Changelog**: https://github.com/Sean-mn/ssak-ssak/compare/v0.0.1...v0.0.2" "$(grep 'Full Changelog' <<<"$out")"
git tag -d v0.0.1 >/dev/null
check "first release link" "**Full Changelog**: https://github.com/Sean-mn/ssak-ssak/commits/v0.0.2" \
  "$(bash "$notes" v0.0.2 | grep 'Full Changelog')"

echo "# pr-title.sh"
title="$skills/../.github/pr-title.sh"
t() { bash "$title" "$@" >/dev/null 2>&1; echo $?; }
check "type title" "0" "$(t "feat(review): add x" 0.9.0 0.9.0)"
check "release title" "0" "$(t "release v0.10.0: multi-pr review, shared agents" 0.9.0 0.10.0)"
check "unknown type" "1" "$(t "feature: add x" 0.9.0 0.9.0)"
check "uppercase release" "1" "$(t "release v0.10.0: Multi-PR review" 0.9.0 0.10.0)"
check "release title, other version" "1" "$(t "release v0.10.1: x" 0.9.0 0.10.0)"
check "release without bump" "1" "$(t "release v0.9.0: x" 0.9.0 0.9.0)"
check "bump outside a release" "1" "$(t "chore: release 0.10.0" 0.9.0 0.10.0)"

# gh stub for the scripts that talk to GitHub: answers from env, logs pr create's args
mkdir "$tmp/bin2" && cat > "$tmp/bin2/gh" <<'EOF'
#!/bin/sh
case "$*" in
  "api user"*) echo me ;;
  "repo view me/"*) echo "${STUB_PARENT:-other/repo}" ;;
  "repo view"*) echo "${STUB_DEFAULT_BRANCH:-main}" ;;
  "repo set-default"*) ;;
  "label list"*) printf '%s' "${STUB_LABELS:-}" ;;
  "pr view"*) echo "$STUB_HEAD" ;;
  "pr create"*) echo "$*" > "$STUB_LOG"; echo https://github.com/other/repo/pull/9 ;;
  "pr list"*) printf '%s' "${STUB_OPEN_PR:-}" ;;
  "api graphql"*pullRequest*) printf '%s\n' "${STUB_GRAPHQL:-none}" ;;
  *"-X POST"*) echo "$*" >> "${STUB_POSTS:-/dev/null}"; echo https://github.com/o/r/pull/7#pullrequestreview-1 ;;
  "api repos/other/repo/contents/"*".md"*) echo "rule text" ;;
  "api repos/other/repo/contents/"*) printf '%s\n' "${STUB_CONTENTS:-}" ;;
  "api repos/"*) echo "$STUB_REVIEWS" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$tmp/bin2/gh"
stub() { PATH="$tmp/bin2:$PATH" "$@"; }
export STUB_HEAD=abc123 STUB_REVIEWS='' STUB_LOG="$tmp/pr-create.log"

echo "# post-review.sh"
post="$skills/ssak-review/scripts/post-review.sh"
p="$tmp/payload.json"
pr7() { stub bash "$post" 7 "$p" 2>/dev/null; echo "$?"; }
printf '{"commit_id": "abc123", "event": "COMMENT", "comments": [{"path": "a", "line": 1, "body": "say \\"event\\": \\"APPROVE\\""}]}' > "$p"
check "posts a COMMENT review" "https://github.com/o/r/pull/7#pullrequestreview-1
0" "$(pr7)"
printf '{"commit_id": "abc123", "event": "APPROVE"}' > "$p"
check "refuses APPROVE" "2" "$(pr7)"
printf '{"commit_id": "abc123", "event": "COMMENT", "event": "REQUEST_CHANGES"}' > "$p"
check "refuses two events" "2" "$(pr7)"
printf '{"commit_id": "old", "event": "COMMENT"}' > "$p"
check "refuses a stale head" "2" "$(pr7)"
printf '{"commit_id": "abc123", "event": "COMMENT"}' > "$p"
check "refuses a second review of the head" "2" "$(STUB_REVIEWS=https://x pr7)"

echo "# prior-review.sh"
prior="$skills/ssak-review/scripts/prior-review.sh"
bash "$prior" abc >/dev/null 2>&1
check "rejects non-number" "2" "$?"
check "asks GitHub for the PR's reviews" "none" "$(stub bash "$prior" 7)"

echo "# review-threads.sh, post-replies.sh"
threads="$skills/ssak-respond/scripts/review-threads.sh"
replies="$skills/ssak-respond/scripts/post-replies.sh"
bash "$threads" abc >/dev/null 2>&1
check "review-threads rejects non-number" "2" "$?"
check "review-threads asks GitHub for the PR's threads" "none" "$(stub bash "$threads" 7)"
on_pr=$(git -C "$repo" rev-parse HEAD)
local_only=$(git -C "$repo" commit-tree -p "$on_pr" -m local "$on_pr^{tree}")
export STUB_POSTS="$tmp/posts.log"
: > "$STUB_POSTS"
echo "Leaving this as is." > "$tmp/r1.md"
echo "Fixed in ${local_only:0:10}: handles the empty list." > "$tmp/r2.md"
echo "Fixed in ${on_pr:0:10}: handles the empty list." > "$tmp/r3.md"
: > "$tmp/empty.md"
# reply [pr line] -- <id>:<file>...: the PR has an open (11), a resolved (12) and an answered (13) thread
reply() {
  local prline="OPEN mine"
  if [ "$1" != -- ]; then prline=$1; shift; fi
  shift
  (cd "$repo" && STUB_GRAPHQL="pr $prline $on_pr
t 11 open
t 12 resolved
t 13 answered" stub bash "$replies" 7 "$@" 2>/dev/null; echo "$?")
}
check "refuses no replies" "2" "$(reply --)"
check "refuses an empty body" "2" "$(reply -- "11:$tmp/empty.md")"
check "refuses a merged PR" "2" "$(reply "MERGED mine" -- "11:$tmp/r1.md")"
check "refuses someone else's PR" "2" "$(reply "OPEN other" -- "11:$tmp/r1.md")"
check "refuses a resolved thread" "2" "$(reply -- "12:$tmp/r1.md")"
check "refuses an id that is not a thread" "2" "$(reply -- "99:$tmp/r1.md")"
check "refuses a commit that is not pushed" "2" "$(reply -- "11:$tmp/r2.md")"
check "one bad reply stops them all" "2" "$(reply -- "11:$tmp/r1.md" "99:$tmp/r1.md")"
check "nothing posted so far" "0" "$(grep -c . "$STUB_POSTS")"
check "replies, and skips a thread I answered last" "replied 11 https://github.com/o/r/pull/7#pullrequestreview-1
skip 13: you already replied last
0" "$(reply -- "11:$tmp/r3.md" "13:$tmp/r1.md")"
check "posted one reply, to that thread" "1" "$(grep -c 'pulls/7/comments/11/replies -X POST -F body=@-' "$STUB_POSTS")"

echo "# open-pr.sh"
openpr="$skills/ssak-contrib/scripts/open-pr.sh"
git init -q --bare "$tmp/me/repo.git"
git clone -q --bare "$tmp/origin.git" "$tmp/other/repo.git" 2>/dev/null
git remote add fork "$tmp/me/repo.git"
git remote add upstream "$tmp/other/repo.git"
git branch -q ssak/contrib-5
echo body > "$tmp/body.md"
op() { stub bash "$openpr" "$repo" "$1" "$2" other/repo main "a title" "$tmp/body.md" 2>/dev/null; echo "$?"; }
check "refuses upstream" "2" "$(op upstream ssak/contrib-5)"
check "refuses a non-contrib branch" "2" "$(op fork main)"
check "pushes to the fork, opens a draft" "https://github.com/other/repo/pull/9
0" "$(op fork ssak/contrib-5)"
check "draft with fork head" "1" "$(grep -c -- '--draft --base main --head me:ssak/contrib-5' "$STUB_LOG")"
check "branch on the fork" "$(git rev-parse ssak/contrib-5)" "$(git -C "$tmp/me/repo.git" rev-parse ssak/contrib-5)"
git branch -q feat/x
check "issue branch: refuses another repo's remote" "2" "$(op fork feat/x)"
check "issue branch: refuses the default branch" "2" "$(op upstream main)"
check "issue branch: refuses a missing branch" "2" "$(op upstream feat/none)"
check "issue branch: pushes to the repo, opens a draft" "https://github.com/other/repo/pull/9
0" "$(op upstream feat/x)"
check "draft with same-repo head" "1" "$(grep -c -- '--draft --base main --head feat/x ' "$STUB_LOG")"
check "issue branch on the repo" "$(git rev-parse feat/x)" "$(git -C "$tmp/other/repo.git" rev-parse feat/x)"
git commit -q --allow-empty -m more && git branch -q -f feat/x HEAD && git reset -q --hard HEAD~1
: > "$STUB_LOG"
check "rerun: pushes to my open PR, opens none" "https://github.com/other/repo/pull/8
0" "$(STUB_OPEN_PR='https://github.com/other/repo/pull/8 me' op upstream feat/x)"
check "rerun: no second PR" "" "$(cat "$STUB_LOG")"
check "rerun: new commit on the repo" "$(git rev-parse feat/x)" "$(git -C "$tmp/other/repo.git" rev-parse feat/x)"
check "refuses someone else's open PR from the branch" "2" "$(STUB_OPEN_PR='https://github.com/other/repo/pull/8 them' op upstream feat/x)"

echo "# setup-fork.sh"
setupfork="$skills/ssak-contrib/scripts/setup-fork.sh"
bash "$setupfork" bad 1 >/dev/null 2>&1
check "setup-fork rejects bad repo" "2" "$?"
bash "$setupfork" other/repo abc >/dev/null 2>&1
check "setup-fork rejects bad issue" "2" "$?"
check "setup-fork reuses clone and creates branch" "fork me/repo
push-remote fork
base upstream/main
path $root
branch ssak/contrib-8" "$(stub bash "$setupfork" other/repo 8 main)"
echo dirty > "$repo/dirty"
stub bash "$setupfork" other/repo 8 main >/dev/null 2>&1
check "setup-fork exits 3 on dirty clone" "3" "$?"
rm -f "$repo/dirty" && git switch -q main

echo "# guidelines.sh, find-issues.sh, issue-status.sh"
guidelines="$skills/ssak-contrib/scripts/guidelines.sh"
findissues="$skills/ssak-issue/scripts/find-issues.sh"
issuestatus="$skills/ssak-contrib/scripts/issue-status.sh"
bash "$guidelines" bad >/dev/null 2>&1
check "guidelines rejects bad repo" "2" "$?"
check "guidelines extracts rules and changeset note" "===== note =====
.changeset/ directory exists: changesets are likely required.

===== CONTRIBUTING.md =====
rule text" "$(STUB_CONTENTS="$(printf 'dir .changeset .changeset\nfile CONTRIBUTING.md CONTRIBUTING.md\nfile README.md README.md')" stub bash "$guidelines" other/repo)"
bash "$findissues" bad >/dev/null 2>&1
check "find-issues rejects bad repo" "2" "$?"
bash "$findissues" other/repo --bad >/dev/null 2>&1
check "find-issues rejects bad flag" "2" "$?"
check "find-issues beginner with no labels" "no beginner labels (good first issue, help wanted, ...) in other/repo" \
  "$(STUB_LABELS='' stub bash "$findissues" other/repo --beginner)"
bash "$issuestatus" bad 1 >/dev/null 2>&1
check "issue-status rejects bad repo" "2" "$?"
bash "$issuestatus" other/repo 0 >/dev/null 2>&1
check "issue-status rejects bad issue" "2" "$?"

echo "# find-issues.sh, issue-status.sh grouping (gh jq)"
if gh auth status >/dev/null 2>&1; then
  # A gh that answers from fixtures but runs each --jq program through the real gh's own jq
  realgh=$(command -v gh)
  mkdir "$tmp/bin3" && cat > "$tmp/bin3/gh" <<EOF
#!/bin/sh
case "\$1 \$2" in
  "api user") echo me; exit 0 ;;
  "label list") printf '%s\n' "\$STUB_LABELS"; exit 0 ;;
  "api graphql") fixture=\$(cat "\$STUB_FIXTURE") ;;
  "pr view") fixture='{"state": "MERGED", "author": {"login": "them"}}' ;;
  *) exit 1 ;;
esac
prog=
while [ \$# -gt 0 ]; do case \$1 in -q | --jq) prog=\$2; shift ;; esac; shift; done
exec "$realgh" api rate_limit --jq "\$fixture | (\$prog)"
EOF
  chmod +x "$tmp/bin3/gh"
  jqstub() { PATH="$tmp/bin3:$PATH" "$@"; }
  # pr <number> <state> <author> <repo>, issue <number> <title> <assignees> <labels> <closing PRs> <timeline> <comments>
  pr() { printf '{"number": %s, "url": "u/%s", "state": "%s", "author": {"login": "%s"}, "repository": {"nameWithOwner": "%s"}}' "$1" "$1" "$2" "$3" "$4"; }
  logins() { local o='' l; for l in "$@"; do o="$o${o:+, }{\"login\": \"$l\"}"; done; echo "$o"; }
  issue() {
    printf '{"number": %s, "title": "%s", "url": "u/i%s", "state": "OPEN", "stateReason": null, "updatedAt": "2026-01-0%sT00:00:00Z",' "$1" "$2" "$1" "$1"
    printf ' "assignees": {"nodes": [%s]}, "labels": {"nodes": [%s]},' "$3" "$4"
    printf ' "closedByPullRequestsReferences": {"nodes": [%s]}, "timelineItems": {"nodes": [%s]}, "comments": {"totalCount": %s, "nodes": [%s]}}' "$5" "$6" "$7" "${8:-}"
  }
  comment() { printf '{"createdAt": "2026-01-02T00:00:00Z", "author": {"login": "%s"}, "body": "%s"}' "$1" "$2"; }
  { printf '{"data": {"search": {"issueCount": 42, "nodes": ['
    issue 1 "Plain bug" "" "" "" "" 0; printf ,
    issue 2 "Mine" "$(logins me)" "" "" "" 0; printf ,
    issue 3 "Claimed" "" "" "" "" 1 "$(comment them "I will take this one")"; printf ,
    issue 4 "Triage" "" '{"name": "needs triage"}' "" "" 0; printf ,
    issue 5 "Closing PR" "" "" "$(pr 50 OPEN them other/repo)" "" 0; printf ,
    issue 6 "Assigned" "$(logins them)" "" "" "" 0; printf ,
    issue 7 "Closed PR" "" "" "$(pr 70 CLOSED them other/repo)" "" 0; printf ,
    issue 8 "Mentioned elsewhere" "" "" "" "{\"__typename\": \"CrossReferencedEvent\", \"source\": $(pr 80 OPEN them fork/repo)}" 0; printf ,
    issue 9 "Mentioned here" "" "" "" "{\"__typename\": \"CrossReferencedEvent\", \"source\": $(pr 90 OPEN them other/repo)}" 0
    printf ']}}}'; } > "$tmp/search.json"
  check "find-issues groups issues" "query: repo:other/repo is:issue is:open sort:updated-desc
matched 42, showing 9
FREE:
  #2 Mine · updated 2026-01-02 · 0 comments · assigned to you
  #1 Plain bug · updated 2026-01-01 · 0 comments
  #7 Closed PR · updated 2026-01-07 · 0 comments
  #8 Mentioned elsewhere · updated 2026-01-08 · 0 comments
CLAIMED (read the claim before taking):
  #3 Claimed · updated 2026-01-03 · 1 comments
    claim: 2026-01-02 them: I will take this one
NOT READY (labels say wait):
  #4 Triage [needs triage] · updated 2026-01-04 · 0 comments
    needs triage
TAKEN (skip):
  #5 Closing PR · updated 2026-01-05 · 0 comments
    PR other/repo#50 OPEN by them [closes]
  #6 Assigned · updated 2026-01-06 · 0 comments
    assigned: them
  #9 Mentioned here · updated 2026-01-09 · 0 comments
    PR other/repo#90 OPEN by them [mentions]" "$(STUB_FIXTURE="$tmp/search.json" jqstub bash "$findissues" other/repo)"
  check "find-issues beginner query" "query: repo:other/repo is:issue is:open sort:updated-desc no:assignee label:\"good first issue\",\"help wanted\"" \
    "$(STUB_LABELS="$(printf 'bug\ngood first issue\nhelp wanted')" STUB_FIXTURE="$tmp/search.json" jqstub bash "$findissues" other/repo --beginner | head -1)"
  { printf '{"data": {"repository": {"issue": '
    issue 3 "Claimed" "$(logins them)" '{"name": "bug"}' "$(pr 50 CLOSED them other/repo)" "{\"__typename\": \"ConnectedEvent\", \"subject\": $(pr 51 OPEN them other/repo)}" 2 \
      "$(comment them "I will take this one"), $(comment rev "Maybe see https://github.com/up/lib/pull/12 and #13, not #3")"
    printf '}}}'; } > "$tmp/issue.json"
  check "issue-status reports what decides the issue" "me: me
issue: Claimed
url: u/i3
state: OPEN 
assignees: them
labels: bug
linked PRs (closes = closing keyword, linked/unlinked = Development sidebar, mentions = PR references the issue):
  other/repo#50 CLOSED by them [closes]
  other/repo#51 OPEN by them [linked]
claim comments:
  2026-01-02 them: I will take this one
last comments (2 of 2):
  2026-01-02 them: I will take this one
  2026-01-02 rev: Maybe see https://github.com/up/lib/pull/12 and #13, not #3
PRs linked in comments:
  other/repo#13 MERGED by them
  up/lib#12 MERGED by them" "$(STUB_FIXTURE="$tmp/issue.json" jqstub bash "$issuestatus" other/repo 3)"
else
  echo "skip (gh not logged in)"
fi

echo "# claim regex, prior review, review threads (gh jq)"
if gh auth status >/dev/null 2>&1; then
  # shellcheck source=skills/ssak-issue/scripts/common.sh
  . "$skills/ssak-issue/scripts/common.sh"
  cases='["I will take this", "Can I work on this issue?", "I am working on it now", "/assign",
    "please assign this to me", "Thanks for the fix!", "Can it be fixed in 2.0?", "/takeover"]'
  check "claims" "true,true,true,true,true,false,false,false" \
    "$(gh api rate_limit --jq "$JQ_DEFS $cases | map(test(claim_re; \"i\") | tostring) | join(\",\")")"
  # shellcheck source=skills/ssak-review/scripts/common.sh
  . "$skills/ssak-review/scripts/common.sh"
  data='{"data": {"viewer": {"login": "me"}, "repository": {"pullRequest": {
    "reviews": {"nodes": [{"state": "COMMENTED", "url": "u/old", "commit": {"oid": "aaa"}, "author": {"login": "me"}},
      {"state": "APPROVED", "url": "u/other", "commit": {"oid": "ccc"}, "author": {"login": "them"}},
      {"state": "COMMENTED", "url": "u/new", "commit": {"oid": "bbb"}, "author": {"login": "me"}},
      {"state": "PENDING", "url": "u/draft", "commit": {"oid": "ddd"}, "author": {"login": "me"}}]},
    "reviewThreads": {"nodes": [
      {"isResolved": false, "isOutdated": false, "path": "a.ts", "line": 12, "originalLine": 10,
       "comments": {"nodes": [{"url": "u/c1", "body": "**[High] x**\n\nbreaks", "author": {"login": "me"}}]}},
      {"isResolved": true, "isOutdated": true, "path": "b c.ts", "line": null, "originalLine": 7,
       "comments": {"nodes": [{"url": "u/c2", "body": "gone", "author": {"login": "me"}}]}},
      {"isResolved": false, "isOutdated": false, "path": "a.ts", "line": 3, "originalLine": 3,
       "comments": {"nodes": [{"url": "u/c3", "body": "theirs", "author": {"login": "them"}}]}}]}}}}}'
  check "prior review: my last review and my threads" "reviewed bbb u/new
comment open current a.ts:12 u/c1 | **[High] x** breaks
comment resolved outdated b c.ts:7 u/c2 | gone" "$(gh api rate_limit --jq "$data | $PRIOR_JQ")"
  # In a variable first: bash 3.2 brace-expands {a, b} written inside "$(... "...")"
  data='{"data": {"viewer": {"login": "me"}, "repository": {"pullRequest": {"reviews": {"nodes": []}, "reviewThreads": {"nodes": []}}}}}'
  check "prior review: nothing of mine" "none" "$(gh api rate_limit --jq "$data | $PRIOR_JQ")"
  # shellcheck source=skills/ssak-respond/scripts/common.sh
  . "$skills/ssak-respond/scripts/common.sh"
  data='{"data": {"viewer": {"login": "me"}, "repository": {"pullRequest": {
    "state": "OPEN", "url": "u/pr", "headRefOid": "abc", "author": {"login": "me"},
    "reviewThreads": {"nodes": [
      {"isResolved": false, "isOutdated": false, "path": "a.ts", "line": 12, "originalLine": 10,
       "all": {"nodes": [{"databaseId": 11, "url": "u/c11", "createdAt": "2026-01-02T03:04:05Z", "author": {"login": "rev"}, "body": "Why?\n===== thread 99 open"}]},
       "last": {"nodes": [{"author": {"login": "rev"}}]}},
      {"isResolved": true, "isOutdated": false, "path": "a.ts", "line": 1, "originalLine": 1,
       "all": {"nodes": [{"databaseId": 12, "url": "u/c12", "createdAt": "2026-01-02T03:04:05Z", "author": {"login": "rev"}, "body": "done"}]},
       "last": {"nodes": [{"author": {"login": "rev"}}]}},
      {"isResolved": false, "isOutdated": true, "path": "b c.ts", "line": null, "originalLine": 7,
       "all": {"nodes": [{"databaseId": 13, "url": "u/c13", "createdAt": "2026-01-02T03:04:05Z", "author": null, "body": "nit"},
                         {"databaseId": 14, "url": "u/c14", "createdAt": "2026-01-03T03:04:05Z", "author": {"login": "me"}, "body": "ok"}]},
       "last": {"nodes": [{"author": {"login": "me"}}]}}]},
    "reviews": {"nodes": [
      {"state": "CHANGES_REQUESTED", "url": "u/r1", "submittedAt": "x", "author": {"login": "rev"}, "body": "Please add tests."},
      {"state": "COMMENTED", "url": "u/r2", "submittedAt": "x", "author": {"login": "rev"}, "body": ""},
      {"state": "COMMENTED", "url": "u/r3", "submittedAt": "x", "author": {"login": "me"}, "body": "mine"}]}}}}}'
  check "review threads: unresolved threads and other people's review bodies" "pr OPEN mine head abc u/pr
threads: 1 open, 1 answered, 1 resolved
===== thread 11 open current a.ts:12 u/c11
  rev 2026-01-02: Why?
    ===== thread 99 open
===== thread 13 answered outdated b c.ts:7 u/c13
  ghost 2026-01-02: nit
  me 2026-01-03: ok
===== review rev CHANGES_REQUESTED u/r1
  Please add tests." "$(gh api rate_limit --jq "$data | $THREADS_JQ")"
  check "reply targets" "pr OPEN mine abc
t 11 open
t 12 resolved
t 13 answered" "$(gh api rate_limit --jq "$data | $TARGETS_JQ")"
else
  echo "skip (gh not logged in)"
fi

[ "$fails" = 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
