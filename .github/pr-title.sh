#!/usr/bin/env bash
# Check a PR title: release notes group squash commits by its type, and release.yml publishes any new version
# that lands on main, so only a "release vX.Y.Z: ..." PR may change the version, and only to X.Y.Z.
#   bash .github/pr-title.sh "<title>" <base version> <head version>
set -euo pipefail

title=${1:?usage: $0 <title> <base version> <head version>}
base=${2:?usage: $0 <title> <base version> <head version>}
head=${3:?usage: $0 <title> <base version> <head version>}
release_re='^release v([0-9]+\.[0-9]+\.[0-9]+): [^[:upper:]]+$'
type_re='^(feat|fix|docs|ci|test|refactor|chore)(\([^)]+\))?!?: .'

if [[ "$title" =~ $release_re ]]; then
  v=${BASH_REMATCH[1]}
  [ "$v" = "$head" ] || { echo "title says v$v but plugin.json is $head" >&2; exit 1; }
  [ "$base" != "$head" ] || { echo "a release PR must bump the version (still $head)" >&2; exit 1; }
elif [[ "$title" =~ $type_re ]]; then
  [ "$base" = "$head" ] || { echo "version changed $base -> $head: only a \"release v$head: ...\" PR may change it" >&2; exit 1; }
else
  echo "title must be \"<type>: <what changed>\" with type feat, fix, docs, ci, test, refactor or chore," >&2
  echo "or \"release vX.Y.Z: <highlights>\" in lowercase" >&2
  exit 1
fi
echo ok
