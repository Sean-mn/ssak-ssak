#!/usr/bin/env bash
# Check out PR <n>'s head in a detached worktree at .claude/worktrees/ssak-review-<n> (reused on rerun).
# Output: "<head sha> <path>"
set -euo pipefail

n=${1:-}
[[ "$n" =~ ^[1-9][0-9]*$ ]] || { echo "usage: $0 <pr-num>" >&2; exit 2; }

root=$(git rev-parse --show-toplevel)
path="$root/.claude/worktrees/ssak-review-$n"

# Keep worktrees out of the main checkout's git status (tracked files untouched)
info="$(git rev-parse --git-common-dir)/info"
mkdir -p "$info"
grep -qxF '.claude/worktrees/' "$info/exclude" 2>/dev/null || echo '.claude/worktrees/' >> "$info/exclude"

# Fetch from the repo gh resolves the PR in, so fork setups (origin = fork) still work
url=$(gh repo view --json url -q .url)
GIT_TERMINAL_PROMPT=0 git fetch -q "$url" "pull/$n/head"
sha=$(git rev-parse FETCH_HEAD)

if [ -d "$path" ]; then
  git -C "$path" checkout -q --detach "$sha"
else
  git worktree add -q --detach "$path" "$sha" >&2
fi
echo "$sha $path"
