"""Static checks for the ssak-ssak plugin. Run from the repo root: python .github/check.py (needs PyYAML).
Set BASE_SHA (e.g. BASE_SHA=origin/main) to also require a version bump when plugin files changed since that commit."""
import json
import os
import pathlib
import re
import subprocess
import sys

import yaml

root = pathlib.Path(__file__).resolve().parent.parent
errors = []


def rel(path):
    return path.relative_to(root).as_posix()


def frontmatter(path):
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        errors.append(f"{rel(path)}: no frontmatter")
        return {}
    try:
        data = yaml.safe_load(text.split("---", 2)[1])
    except yaml.YAMLError as e:
        errors.append(f"{rel(path)}: frontmatter is not valid YAML: {e}")
        return {}
    if not isinstance(data, dict):
        errors.append(f"{rel(path)}: frontmatter is not a mapping")
        return {}
    for key in ("name", "description"):
        if not isinstance(data.get(key), str) or not data[key].strip():
            errors.append(f"{rel(path)}: '{key}' must be a non-empty string")
    if "argument-hint" in data and not isinstance(data["argument-hint"], str):
        errors.append(f"{rel(path)}: argument-hint must be a string (quote it if it starts with '[')")
    return data


manifests = {}
for path in sorted([*root.glob(".claude-plugin/*.json"), *root.glob(".codex-plugin/*.json"), *root.glob(".agents/plugins/*.json")]):
    try:
        manifests[path.relative_to(root).as_posix()] = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        errors.append(f"{rel(path)}: invalid JSON: {e}")

claude = manifests.get(".claude-plugin/plugin.json", {})
codex = manifests.get(".codex-plugin/plugin.json", {})
if claude.get("version") != codex.get("version"):
    errors.append(f"version mismatch: .claude-plugin {claude.get('version')} vs .codex-plugin {codex.get('version')}")

for agent in claude.get("agents", []):
    path = root / agent
    if not path.is_file():
        errors.append(f".claude-plugin/plugin.json: agent file missing: {agent}")
    else:
        frontmatter(path)

for skill in sorted(root.glob("skills/*/SKILL.md")):
    data = frontmatter(skill)
    if data.get("name") not in (None, skill.parent.name):
        errors.append(f"{rel(skill)}: name '{data['name']}' does not match folder '{skill.parent.name}'")

# Files skill docs point at (scripts/x.sh, ../ssak-issue/references/y.md) must exist, relative to the skill folder
for doc in sorted(root.glob("skills/*/**/*.md")):
    skill_dir = root / "skills" / doc.relative_to(root / "skills").parts[0]
    for ref in sorted(set(re.findall(r"(?:\.\./[\w-]+/)?(?:scripts|references|agents)/[\w.-]*\w", doc.read_text(encoding="utf-8")))):
        if not (skill_dir / ref).is_file():
            errors.append(f"{rel(doc)}: points at missing file {ref}")


# Installed plugins only update when the version goes up, so plugin changes need a bump
def git(*args):
    return subprocess.run(["git", *args], cwd=root, capture_output=True, text=True)


def version_key(v):
    try:
        return tuple(int(x) for x in str(v).split("."))
    except ValueError:
        return None


base = os.environ.get("BASE_SHA", "").strip()
if base and set(base) != {"0"} and git("cat-file", "-e", f"{base}^{{commit}}").returncode == 0:
    changed = git("diff", "--name-only", base, "HEAD", "--").stdout.split()
    plugin_files = [f for f in changed if f.startswith(("skills/", ".claude-plugin/", ".codex-plugin/", ".agents/"))]
    old = git("show", f"{base}:.claude-plugin/plugin.json")
    if plugin_files and old.returncode == 0:
        old_version = json.loads(old.stdout).get("version")
        new_version = claude.get("version")
        old_key, new_key = version_key(old_version), version_key(new_version)
        if old_key is None or new_key is None or new_key <= old_key:
            errors.append(f"version not bumped: plugin files changed since {base[:12]} ({', '.join(plugin_files[:5])}"
                          f"{', ...' if len(plugin_files) > 5 else ''}) but version is {new_version} (was {old_version})")
elif base and set(base) != {"0"}:  # all zeros = first push of a branch, nothing to compare
    print(f"note: base {base[:12]} not available, skipped the version bump check")

print("\n".join(errors) or f"ok: {len(manifests)} manifests, {len(list(root.glob('skills/*/SKILL.md')))} skills")
sys.exit(1 if errors else 0)
