#!/usr/bin/env bash
# Re-splice the live PoE skills into the setup prompt, so the prompt never carries a
# stale copy. Run after editing SKILL.md or any reference file.
#
#   prompts/sync-pob-skill.sh            # update in place
#   prompts/sync-pob-skill.sh --check    # exit 1 if the prompt is out of date
set -euo pipefail

SKILL_DIR="${SKILL_DIR:-$HOME/.config/opencode/skills/poe-gear-finder}"
PROMPT="${PROMPT:-$(dirname "$(readlink -f "$0")")/pob-gear-finder-setup.md}"
MODE="${1:-}"

[ -f "$SKILL_DIR/SKILL.md" ] || { echo "missing $SKILL_DIR/SKILL.md" >&2; exit 1; }
[ -f "$PROMPT" ] || { echo "missing $PROMPT" >&2; exit 1; }

# Contract lint travels with the sync: this script is what the pre-commit hook runs,
# so run data leaking into SKILL.md/reference/scripts blocks the commit here.
CHECK="$SKILL_DIR/scripts/check.mjs"
if [ -f "$CHECK" ]; then
  node "$CHECK" || exit 1
  for other in "$(dirname "$SKILL_DIR")"/poe-*; do
    [ "$other" = "$SKILL_DIR" ] && continue
    [ -f "$other/SKILL.md" ] || continue
    node "$CHECK" --root "$other" || exit 1
  done
fi

python3 - "$SKILL_DIR" "$PROMPT" "$MODE" <<'PY'
import sys, pathlib
skill_dir, prompt_path, mode = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
skills_root = skill_dir.parent

def collect(skill):
    """Every file the skill needs to run on a fresh machine, in a stable order."""
    d = skills_root / skill
    if not (d / "SKILL.md").exists():
        return []
    out = ["SKILL.md"]
    out += sorted(str(p.relative_to(d)) for p in (d / "reference").glob("*.md"))
    if (d / "scripts" / "README.md").exists():
        out.append("scripts/README.md")
    out += sorted(str(p.relative_to(d)) for p in (d / "scripts").glob("*.mjs"))
    out += sorted(str(p.relative_to(d)) for p in (d / "specs").glob("*.json"))
    if (d / "findings.md").exists():
        out.append("findings.md")
    return [(skill, n) for n in out]

# The gear skill starts every run by profiling the build, so both ship together.
names = collect("poe-gear-finder") + collect("poe-build-profile")

letters = "abcdefghijklmnopqrstuvwxyz"
files = []
for i, (skill, name) in enumerate(names):
    tag = "5" + letters[i] if i < len(letters) else f"5_{i}"
    body = (skills_root / skill / name).read_text().rstrip("\n")
    files.append((tag, f"~/.config/opencode/skills/{skill}/{name}", body))

block = [f"STEP 5 — write the skills ({len(files)} files, exact content):", ""]
for tag, path, body in files:
    block += [f"{tag}) {path}", ""] + body.split("\n") + [""]

lines = prompt_path.read_text().split("\n")
try:
    start = next(i for i, l in enumerate(lines) if l.startswith("STEP 5"))
    end = next(i for i, l in enumerate(lines) if l.startswith("STEP 6"))
except StopIteration:
    sys.exit("prompt is missing STEP 5 or STEP 6 markers")

new = lines[:start] + block + lines[end:]
changed = new != lines

if mode == "--check":
    print("OUT OF DATE" if changed else "in sync")
    sys.exit(1 if changed else 0)

prompt_path.write_text("\n".join(new))
print(f"{'updated' if changed else 'already in sync'}: {prompt_path}")
print(f"block: {len(block)} lines | files: " + ", ".join(p for _, p, _ in files))
PY
