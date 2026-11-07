"""Static checks for the ssak-ssak plugin. Run from the repo root: python .github/check.py (needs PyYAML)."""
import json
import pathlib
import re
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

# Claude Code picks up agents/*.md at the plugin root on its own
for agent in sorted(root.glob("agents/*.md")):
    data = frontmatter(agent)
    if data.get("name") not in (None, agent.stem):
        errors.append(f"{rel(agent)}: name '{data['name']}' does not match '{agent.stem}'")
    if not isinstance(data.get("model"), str) or not data["model"].strip():
        errors.append(f"{rel(agent)}: 'model' must be a non-empty string")
    if agent.stem != "ssak-reviewer" and (not isinstance(data.get("effort"), str) or not data["effort"].strip()):
        errors.append(f"{rel(agent)}: 'effort' must be a non-empty string")
    if agent.stem != "ssak-worker" and data.get("tools") != "Read, Grep, Glob, Bash":
        errors.append(f"{rel(agent)}: checking agents must have tools 'Read, Grep, Glob, Bash'")

skill_names = {s.parent.name for s in root.glob("skills/*/SKILL.md")}
for skill in sorted(root.glob("skills/*/SKILL.md")):
    data = frontmatter(skill)
    if data.get("name") not in (None, skill.parent.name):
        errors.append(f"{rel(skill)}: name '{data['name']}' does not match folder '{skill.parent.name}'")
    if not isinstance(data.get("argument-hint"), str) or not data["argument-hint"].strip():
        errors.append(f"{rel(skill)}: 'argument-hint' must be a non-empty string")
    raw_fm = skill.read_text(encoding="utf-8").split("---", 2)[1] if skill.read_text(encoding="utf-8").startswith("---") else ""
    if not re.search(r"(?m)^#\s*for:\s*\S", raw_fm):
        errors.append(f"{rel(skill)}: frontmatter is missing a '# for:' comment")

for case in sorted(root.glob("evals/*/case.yaml")):
    try:
        cdata = yaml.safe_load(case.read_text(encoding="utf-8"))
    except yaml.YAMLError as e:
        errors.append(f"{rel(case)}: invalid YAML: {e}")
        continue
    if not isinstance(cdata, dict) or cdata.get("name") != case.parent.name:
        errors.append(f"{rel(case)}: name must match folder '{case.parent.name}'")
        continue
    if not isinstance((cdata.get("execution") or {}).get("prompt"), str) or not cdata.get("graders"):
        errors.append(f"{rel(case)}: must have execution.prompt and graders")
    for grader in cdata.get("graders") or []:
        for ref in re.findall(r"ssak-[a-z-]+", grader.get("input_match") or ""):
            if ref != "ssak-" and ref not in skill_names:
                errors.append(f"{rel(case)}: unknown skill '{ref}'")

# Every skill has a row in both READMEs' skills table
for readme in ("README.md", "README.ko.md"):
    text = (root / readme).read_text(encoding="utf-8")
    for skill in sorted(root.glob("skills/*/SKILL.md")):
        if f"| `/{skill.parent.name}" not in text:
            errors.append(f"{readme}: no row for /{skill.parent.name} in the skills table")

# Files skill docs point at (scripts/x.sh, ../ssak-issue/references/y.md, ../../agents/z.md) must exist, relative to the skill folder
for doc in sorted(root.glob("skills/*/**/*.md")):
    skill_dir = root / "skills" / doc.relative_to(root / "skills").parts[0]
    for ref in sorted(set(re.findall(r"(?:\.\./\.\./|\.\./[\w-]+/)?(?:scripts|references|agents)/[\w.-]*\w", doc.read_text(encoding="utf-8")))):
        if not (skill_dir / ref).is_file():
            errors.append(f"{rel(doc)}: points at missing file {ref}")

# Files scripts run or source next to themselves ("$(dirname "$0")/common.sh") must exist, relative to the script
for script in sorted(root.glob("skills/*/scripts/*.sh")):
    for ref in sorted(set(re.findall(r'\$\(dirname "\$0"\)/([\w./-]*\w)', script.read_text(encoding="utf-8")))):
        if not (script.parent / ref).is_file():
            errors.append(f"{rel(script)}: points at missing file {ref}")

print("\n".join(errors) or f"ok: {len(manifests)} manifests, {len(list(root.glob('skills/*/SKILL.md')))} skills")
sys.exit(1 if errors else 0)
