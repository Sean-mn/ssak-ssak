#!/usr/bin/env bash
# Print the ref to branch issues from: develop-like > origin default branch > main > master (remote refs first).
# A develop-like branch with nothing the default branch lacks is stale or unused, so it is skipped.
set -euo pipefail

GIT_TERMINAL_PROMPT=0 git fetch -q origin 2>/dev/null || true

has() { git rev-parse -q --verify "$1^{commit}" >/dev/null; }

head=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)

# shortcut: an abandoned develop that still has unmerged commits wins; check where recent PRs merge if that bites
for b in develop dev development; do
  for ref in "origin/$b" "$b"; do
    has "$ref" || continue
    [ -n "$head" ] && git merge-base --is-ancestor "$ref" "$head" && continue
    echo "$ref"; exit 0
  done
done

[ -n "$head" ] && { echo "$head"; exit 0; }

for ref in origin/main main origin/master master; do
  has "$ref" && { echo "$ref"; exit 0; }
done

echo "base branch not found" >&2
exit 1
