#!/usr/bin/env bash
# Print <owner/repo>'s contribution rule files from GitHub without cloning or forking.
# Looks in /, .github/, docs/ and .github/PULL_REQUEST_TEMPLATE/; each file is printed under "===== <path> =====".
set -euo pipefail

repo=${1:-}
[[ "$repo" =~ ^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$ ]] || { echo "usage: $0 <owner/repo>" >&2; exit 2; }
gh repo view "$repo" --json name >/dev/null

# Basenames that carry contribution rules (case-insensitive, any extension)
pattern='^((contributing|pull_request_template|ai[_-]?(policy|usage|contributions?)|agents|claude|dco|cla)([.]|$)|[.]?commitlint)'

paths=$(for dir in "" .github docs .github/PULL_REQUEST_TEMPLATE; do
  gh api "repos/$repo/contents/$dir" --jq '.[] | "\(.type) \(.path) \(.name)"' 2>/dev/null || true
done)

[ -n "$(awk '$1=="dir" && $2==".changeset"' <<<"$paths")" ] && printf '===== note =====\n.changeset/ directory exists: changesets are likely required.\n\n'

awk -v p="$pattern" '$1=="file" { n=tolower($3); if (n ~ p || $2 ~ /^\.github\/PULL_REQUEST_TEMPLATE\//) print $2 }' <<<"$paths" | sort -u |
while read -r f; do
  printf '===== %s =====\n' "$f"
  gh api "repos/$repo/contents/$f" -H "Accept: application/vnd.github.raw"
  printf '\n\n'
done
