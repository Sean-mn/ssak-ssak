#!/usr/bin/env bash
# Tests for the skill scripts in a throwaway git repo (local bare origin, no network).
# The claim regex test runs through gh's own jq and is skipped when gh is not logged in.
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
# gh stub keeps tests offline: pr-worktree.sh gets the local origin as the PR's repo, cleanup.sh's PR lookup fails
mkdir "$tmp/bin" && printf '#!/bin/sh\n[ "$1 $2" = "repo view" ] && echo "%s" && exit 0\nexit 1\n' "$tmp/origin.git" > "$tmp/bin/gh" && chmod +x "$tmp/bin/gh"
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
check "checks out PR head" "$pr $wt/ssak-review-7" "$(offline bash "$review" 7 2>&1)"
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

echo "# claim regex (gh jq)"
if gh auth status >/dev/null 2>&1; then
  # shellcheck source=skills/ssak-issue/scripts/common.sh
  . "$skills/ssak-issue/scripts/common.sh"
  cases='["I will take this", "Can I work on this issue?", "I am working on it now", "/assign",
    "please assign this to me", "Thanks for the fix!", "Can it be fixed in 2.0?", "/takeover"]'
  check "claims" "true,true,true,true,true,false,false,false" \
    "$(gh api rate_limit --jq "$JQ_DEFS $cases | map(test(claim_re; \"i\") | tostring) | join(\",\")")"
else
  echo "skip (gh not logged in)"
fi

[ "$fails" = 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
