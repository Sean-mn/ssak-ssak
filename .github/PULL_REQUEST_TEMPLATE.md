<!-- Title: "<type>: <what changed>", type is feat, fix, docs, ci, test, refactor or chore.
     It becomes the commit subject on squash merge, and release notes group commits by that type. -->

## Summary
<!-- What changes and why, in 2-4 sentences. Add "Fixes #<issue#>" if it closes an issue. -->

## Changes
- 

## Testing
<!-- CI runs check.py and tests/run.sh. After changing a skill's description, also run the trigger evals:
     claude plugin eval . --runs 1 --ablation none --no-publish
     List what else you ran (e.g. a skill on a real repo) and the result. -->
- 

## Checklist
- [ ] Changed `skills/` or a manifest: version bumped in both `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` (merging publishes a release)
- [ ] New or changed command: skills table updated in both README.md and README.ko.md
