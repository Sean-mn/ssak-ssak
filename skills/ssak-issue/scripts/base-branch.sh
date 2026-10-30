#!/usr/bin/env bash
# Print the ref to branch issues from: develop-like > origin default branch > main > master (remote refs first)
set -euo pipefail

GIT_TERMINAL_PROMPT=0 git fetch -q origin 2>/dev/null || true

has() { git rev-parse -q --verify "$1^{commit}" >/dev/null; }

for b in develop dev development; do
  for ref in "origin/$b" "$b"; do
    has "$ref" && { echo "$ref"; exit 0; }
  done
done

head=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)
[ -n "$head" ] && { echo "$head"; exit 0; }

for ref in origin/main main origin/master master; do
  has "$ref" && { echo "$ref"; exit 0; }
done

echo "base branch not found" >&2
exit 1
