#!/usr/bin/env bash
# Push a branch and open a draft PR on <owner/repo>: the only way ssak-contrib and ssak-issue --pr write to GitHub.
# Usage: open-pr.sh <path> <push-remote> <branch> <owner/repo> <base-branch> <title> <body-file>
# ssak/contrib-<n>: refuses (exit 2) to push to upstream unless the repo is my own.
# Any other branch (ssak-issue): refuses unless <push-remote> is <owner/repo> itself and the branch is not
# <base-branch> or the repo's default branch. Never force-pushes. Always opens a draft.
# Output: the PR URL.
# Requires: bash, git, gh signed in (gh auth login).
set -euo pipefail

path=${1:-}; remote=${2:-}; branch=${3:-}; repo=${4:-}; base=${5:-}; title=${6:-}; body=${7:-}
[[ "$repo" =~ ^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$ ]] && git check-ref-format --branch "$branch" >/dev/null 2>&1 &&
  [ -n "$base" ] && [ -n "$title" ] && [ -f "$body" ] && [ -d "$path" ] ||
  { echo "usage: $0 <path> <push-remote> <branch> <owner/repo> <base-branch> <title> <body-file>" >&2; exit 2; }
git -C "$path" show-ref -q --verify "refs/heads/$branch" || { echo "no local branch $branch" >&2; exit 2; }

body="$(cd "$(dirname "$body")" && pwd)/$(basename "$body")"  # absolute: gh runs from <path>
lc() { tr "A-Z" "a-z" <<<"$1"; }  # portable lowercase (macOS ships bash 3.2)
me=$(gh api user -q .login)
url=$(lc "$(git -C "$path" remote get-url "$remote")"); url=${url%.git}
is_repo() { case $url in */$(lc "$repo") | *:$(lc "$repo")) return 0 ;; esac; return 1; }

if [[ "$branch" =~ ^ssak/contrib-[1-9][0-9]*$ ]]; then
  if [ "$(lc "${repo%%/*}")" = "$(lc "$me")" ]; then
    head=$branch
  else
    ! is_repo || { echo "refused: $remote is upstream $repo; push to your fork" >&2; exit 2; }
    head="$me:$branch"
  fi
else
  is_repo || { echo "refused: $remote is not $repo" >&2; exit 2; }
  default=$(gh repo view "$repo" --json defaultBranchRef -q .defaultBranchRef.name)
  [ "$branch" != "$base" ] && [ "$branch" != "$default" ] ||
    { echo "refused: $branch is the base or default branch" >&2; exit 2; }
  head=$branch
fi

GIT_TERMINAL_PROMPT=0 git -C "$path" push -q -u "$remote" "refs/heads/$branch" >&2
(cd "$path" && gh pr create -R "$repo" --draft --base "$base" --head "$head" --title "$title" --body-file "$body")
