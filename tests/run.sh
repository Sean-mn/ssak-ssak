#!/usr/bin/env bash
# Tests for the skill scripts in a throwaway git repo (local bare origin, no network).
# The claim regex and prior review tests run through gh's own jq and are skipped when gh is not logged in.
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
  "api graphql"*pullRequest*) echo none ;;
  *"-X POST"*) echo https://github.com/o/r/pull/7#pullrequestreview-1 ;;
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

echo "# claim regex, prior review (gh jq)"
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
  check "prior review: nothing of mine" "none" \
    "$(gh api rate_limit --jq "{data: {viewer: {login: \"me\"}, repository: {pullRequest: {reviews: {nodes: []}, reviewThreads: {nodes: []}}}}} | $PRIOR_JQ")"
else
  echo "skip (gh not logged in)"
fi

[ "$fails" = 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
