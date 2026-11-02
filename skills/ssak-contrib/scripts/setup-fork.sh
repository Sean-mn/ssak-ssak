#!/usr/bin/env bash
# Prepare a local clone to contribute to <owner/repo>#<issue>: fork if needed, clone or reuse,
# point gh at upstream, and create ssak/contrib-<issue> from upstream's [base-branch] (default branch if omitted).
# Reuses the current repo if it is a clone of upstream or the fork; otherwise clones next to it (or into cwd).
# Output lines: "fork <owner/name>", "push-remote <remote>", "base <remote>/<branch>", "path <dir>", "branch <name>"
# Exit 3: the clone has uncommitted changes.
set -euo pipefail

repo=${1:-}; n=${2:-}; base=${3:-}
[[ "$repo" =~ ^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$ && "$n" =~ ^[1-9][0-9]*$ ]] || { echo "usage: $0 <owner/repo> <issue#> [base-branch]" >&2; exit 2; }

me=$(gh api user -q .login)
owner=${repo%%/*}; name=${repo#*/}
lc() { tr "A-Z" "a-z" <<<"$1"; }  # portable lowercase (macOS ships bash 3.2)
[ -n "$base" ] || base=$(gh repo view "$repo" --json defaultBranchRef -q .defaultBranchRef.name)

# Fork, unless contributing to my own repo
if [ "$(lc "$owner")" = "$(lc "$me")" ]; then
  fork=$repo
else
  fork="$me/$name"
  parent=$(gh repo view "$fork" --json parent -q '.parent.nameWithOwner // ""' 2>/dev/null || echo missing)
  if [ "$parent" = missing ]; then
    gh repo fork "$repo" --clone=false >&2
  elif [ "$(lc "$parent")" != "$(lc "$repo")" ]; then
    echo "$fork exists but is not a fork of $repo" >&2; exit 1
  fi
fi

# Remote name in $1 whose URL points at GitHub repo $2
remote_for() {
  git -C "$1" remote -v | awk -v r="$(lc "$2")" '
    { u = tolower($2); sub(/\.git$/, "", u) } u ~ ("[:/]" r "$") { print $1; exit }'
}

dir=""
if top=$(git rev-parse --show-toplevel 2>/dev/null); then
  if [ -n "$(remote_for "$top" "$repo")" ] || [ -n "$(remote_for "$top" "$fork")" ]; then dir=$top; fi
fi
if [ -z "$dir" ]; then
  dir="$(dirname "${top:-$PWD/x}")/$name"
  if [ ! -d "$dir/.git" ]; then
    # A new fork can take a few seconds before it is clonable
    for i in 1 2 3 4 5; do gh repo clone "$fork" "$dir" -- -q >&2 && break; [ "$i" = 5 ] && exit 1; sleep 3; done
  fi
fi

up=$(remote_for "$dir" "$repo")
[ -n "$up" ] || { git -C "$dir" remote add upstream "https://github.com/$repo.git"; up=upstream; }
push=$(remote_for "$dir" "$fork")
[ -n "$push" ] || { git -C "$dir" remote add fork "https://github.com/$fork.git"; push=fork; }

(cd "$dir" && gh repo set-default "$repo" >/dev/null)
GIT_TERMINAL_PROMPT=0 git -C "$dir" fetch -q "$up" "$base"

if [ -n "$(git -C "$dir" status --porcelain)" ]; then
  echo "uncommitted changes in $dir" >&2; exit 3
fi

branch="ssak/contrib-$n"
if git -C "$dir" show-ref -q --verify "refs/heads/$branch"; then
  git -C "$dir" switch -q "$branch"
else
  git -C "$dir" switch -q --no-track -c "$branch" "$up/$base"
fi

printf 'fork %s\npush-remote %s\nbase %s/%s\npath %s\nbranch %s\n' "$fork" "$push" "$up" "$base" "$dir" "$branch"
