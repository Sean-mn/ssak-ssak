#!/usr/bin/env bash
# Print the GitHub release body for <tag>: commits since the previous v* tag grouped by type, then update steps.
#   bash .github/release-notes.sh v0.8.0
set -euo pipefail

tag=${1:?usage: $0 <tag>}
repo=https://github.com/Sean-mn/ssak-ssak
prev=$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)
log=$(git log --no-merges --format='%s (%h)' "${prev:+$prev..}HEAD")
type_re='^(feat|fix)(\([^)]*\))?!?: '
changelog="$repo/commits/$tag"
[ -n "$prev" ] && changelog="$repo/compare/$prev...$tag"

section() {  # section <title> <grep args...>
  local lines
  lines=$(grep "${@:2}" <<<"$log") || return 0
  printf '### %s\n\n%s\n\n' "$1" "$(sed -E "s/$type_re//; s/^/- /" <<<"$lines")"
}

echo "## What's changed"
echo
section Features -E '^feat(\([^)]*\))?!?: '
section Fixes -E '^fix(\([^)]*\))?!?: '
section Other -vE "$type_re"
cat <<EOF
## Update

- Claude Code: \`/plugin marketplace update ssak-ssak\`, then update ssak-ssak from \`/plugin\` and restart.
- Codex: \`codex plugin marketplace upgrade\`
- Antigravity: \`git pull\` in your clone, then \`agy plugin install .\`

New install: see [Quick Start]($repo#quick-start).

**Full Changelog**: $changelog
EOF
