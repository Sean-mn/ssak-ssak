#!/usr/bin/env bash
# Create a ssak/issue-<n> branch and .claude/worktrees/ssak-issue-<n> worktree per issue from the base ref.
# Output: first line "base <ref>", then one "issue <n> <branch> <path>" line per issue
set -euo pipefail

[ $# -gt 0 ] || { echo "usage: $0 <issue-num>..." >&2; exit 2; }
for n in "$@"; do
  [[ "$n" =~ ^[1-9][0-9]*$ ]] || { echo "invalid issue number: $n" >&2; exit 2; }
done

root=$(git rev-parse --show-toplevel)
base=$(bash "$(dirname "$0")/base-branch.sh")

# Keep worktrees out of the main checkout's git status (tracked files untouched)
info="$(git rev-parse --git-common-dir)/info"
mkdir -p "$info"
grep -qxF '.claude/worktrees/' "$info/exclude" 2>/dev/null || echo '.claude/worktrees/' >> "$info/exclude"

echo "base $base"
for n in $(printf '%s\n' "$@" | sort -un); do
  branch="ssak/issue-$n"
  path="$root/.claude/worktrees/ssak-issue-$n"
  if [ -d "$path" ]; then
    :  # reuse the worktree from a previous run
  elif git show-ref -q --verify "refs/heads/$branch"; then
    git worktree add -q "$path" "$branch" >&2
  else
    git worktree add -q --no-track -b "$branch" "$path" "$base" >&2
  fi
  echo "issue $n $branch $path"
done
