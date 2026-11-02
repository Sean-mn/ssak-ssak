#!/usr/bin/env bash
# Find and remove what ssak skills leave in this repo: .claude/worktrees/ssak-{issue,review}-<n> worktrees
# and ssak/{issue,contrib}-<n> branches. Remote branches and PRs are never touched.
#   cleanup.sh scan                       one line per id: "<id> <SAFE|RISKY> wt=<path|-> branch=<name|-> | <notes>"
#   cleanup.sh remove [--force] [--keep-branch] <id>...
#                                         re-checks each id; RISKY ids are skipped unless --force.
#                                         --keep-branch removes only the worktree, so only the worktree is checked.
# SAFE = removing loses nothing: no uncommitted changes and every branch commit is on a remote.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
wtdir="$root/.claude/worktrees"

ids() {
  # Prefix match with awk, not a regex: the repo path may contain regex characters such as "(x86)"
  { git worktree list --porcelain | awk -v p="worktree $wtdir/ssak-" 'index($0, p) == 1 { print substr($0, length(p) + 1) }' |
      grep -E '^(issue|review)-[1-9][0-9]*$'
    git for-each-ref --format='%(refname:short)' refs/heads/ssak/ | sed -n 's#^ssak/##p' |
      grep -E '^(issue|contrib)-[1-9][0-9]*$'
  } | sort -u
}

# Sets wt, branch, risky, notes for one id. With a second arg "wt-only", the branch is ignored.
check() {
  local kind=${1%-*} n=${1##*-} only=${2:-} out
  wt=-; branch=-; risky=0; notes=()

  if [ "$kind" != contrib ] && git worktree list --porcelain | grep -qxF "worktree $wtdir/ssak-$kind-$n"; then
    wt="$wtdir/ssak-$kind-$n"
    if [ ! -d "$wt" ]; then
      notes+=("worktree folder already gone")
    elif out=$(git -C "$wt" status --porcelain) && [ -n "$out" ]; then
      risky=1; notes+=("uncommitted changes in worktree")
    fi
  fi

  if [ "$kind" != review ] && [ "$only" != wt-only ] && git show-ref -q --verify "refs/heads/ssak/$kind-$n"; then
    branch="ssak/$kind-$n"
    local at local_only pr
    at=$(git worktree list --porcelain | awk -v b="branch refs/heads/$branch" '/^worktree /{w=substr($0, 10)} $0==b{print w}')
    if [ -n "$at" ] && [ "$at" != "$wt" ]; then
      risky=1; notes+=("branch is checked out in $at")
      [ -z "$(git -C "$at" status --porcelain 2>/dev/null)" ] || notes+=("uncommitted changes in $at")
    fi
    local_only=$(git rev-list --count "$branch" --not --remotes)
    [ "$local_only" = 0 ] || { risky=1; notes+=("$local_only commit(s) not on any remote"); }
    pr=$(gh pr list --head "$branch" --author @me --state all --json number,state -q '.[0] | select(.) | "PR #\(.number) \(.state)"' 2>/dev/null || true)
    [ -z "$pr" ] || notes+=("$pr")
  fi
}

line() {
  local s=SAFE; [ "$risky" = 0 ] || s=RISKY
  local IFS=';'
  echo "$1 $s wt=$wt branch=$branch | ${notes[*]:-nothing to lose}"
}

case ${1:-} in
  scan)
    found=0
    for id in $(ids); do check "$id"; line "$id"; found=1; done
    [ "$found" = 1 ] || echo "nothing to clean"
    ;;
  remove)
    shift; force=0; only=
    while [[ "${1:-}" == --* ]]; do
      case $1 in --force) force=1 ;; --keep-branch) only=wt-only ;; *) echo "unknown option $1" >&2; exit 2 ;; esac
      shift
    done
    [ $# -gt 0 ] || { echo "usage: $0 remove [--force] [--keep-branch] <id>..." >&2; exit 2; }
    for id in "$@"; do
      [[ "$id" =~ ^(issue|review|contrib)-[1-9][0-9]*$ ]] || { echo "skip $id: not an ssak id"; continue; }
      check "$id" "$only"
      if [ "$wt" = - ] && [ "$branch" = - ]; then echo "skip $id: not found"; continue; fi
      if [ "$risky" = 1 ] && [ "$force" = 0 ]; then line "$id" | sed 's/^/skip (needs --force): /'; continue; fi
      if [ "$wt" != - ]; then
        if [ "$force" = 1 ]; then git worktree remove --force "$wt"; else git worktree remove "$wt"; fi
      fi
      if [ "$branch" != - ]; then
        # Even --force cannot delete a branch another checkout is on
        git branch -D "$branch" >/dev/null 2>&1 || { echo "kept $branch: still checked out elsewhere; switch away first"; continue; }
      fi
      if [ -n "$only" ]; then echo "removed $id worktree (kept branch)"; else echo "removed $id"; fi
    done
    git worktree prune
    ;;
  *) echo "usage: $0 scan | remove [--force] [--keep-branch] <id>..." >&2; exit 2 ;;
esac
