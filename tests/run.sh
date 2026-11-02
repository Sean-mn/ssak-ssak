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
# cleanup.sh asks gh for PRs; a failing stub keeps it offline
mkdir "$tmp/bin" && printf '#!/bin/sh\nexit 1\n' > "$tmp/bin/gh" && chmod +x "$tmp/bin/gh"
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

echo "# cleanup.sh"
cleanup="$skills/ssak-clean-up/scripts/cleanup.sh"
git worktree add -q --detach "$wt/ssak-review-7" HEAD
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

echo "# base-branch.sh, develop-like"
git branch -q develop
check "local develop" "develop" "$(bash "$skills/ssak-issue/scripts/base-branch.sh")"
git push -q origin develop 2>/dev/null
check "remote develop first" "origin/develop" "$(bash "$skills/ssak-issue/scripts/base-branch.sh")"

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
