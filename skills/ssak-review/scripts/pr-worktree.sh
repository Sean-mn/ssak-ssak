#!/usr/bin/env bash
# Check out PR <n>'s head in a detached worktree at .claude/worktrees/ssak-review-<n> (reused on rerun).
# Output: "<head sha> <path>", then "fork <yes|no> <author>". "fork yes" means the head is in someone else's fork:
# its code is not run without the user's yes (references/untrusted-content.md).
# Requires: bash, git, gh signed in (gh auth login).
set -euo pipefail

n=${1:-}
[[ "$n" =~ ^[1-9][0-9]*$ ]] || { echo "usage: $0 <pr#>" >&2; exit 2; }

root=$(git rev-parse --show-toplevel)
path="$root/.claude/worktrees/ssak-review-$n"

# "<true|false> <author>", asked before anything is created so a failure leaves nothing behind
pr=$(gh pr view "$n" --json isCrossRepository,author -q '"\(.isCrossRepository) \(.author.login)"')
author=${pr#* }
fork=no
if [ "${pr%% *}" = true ] && [ "$author" != "$(gh api user -q .login)" ]; then fork=yes; fi

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
echo "fork $fork $author"
