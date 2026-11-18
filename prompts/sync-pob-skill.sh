#!/usr/bin/env bash
# Re-splice the live poe-gear-finder skill into the setup prompt, so the prompt
# never carries a stale copy. Run after editing SKILL.md or any reference file.
#
#   prompts/sync-pob-skill.sh            # update in place
#   prompts/sync-pob-skill.sh --check    # exit 1 if the prompt is out of date
set -euo pipefail

SKILL_DIR="${SKILL_DIR:-$HOME/.config/opencode/skills/poe-gear-finder}"
PROMPT="${PROMPT:-$(dirname "$(readlink -f "$0")")/pob-gear-finder-setup.md}"
MODE="${1:-}"

[ -f "$SKILL_DIR/SKILL.md" ] || { echo "missing $SKILL_DIR/SKILL.md" >&2; exit 1; }
[ -f "$PROMPT" ] || { echo "missing $PROMPT" >&2; exit 1; }

python3 - "$SKILL_DIR" "$PROMPT" "$MODE" <<'PY'
import sys, pathlib
skill_dir, prompt_path, mode = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]

def read(name):
    p = skill_dir / name
    return p.read_text().rstrip("\n")

files = [
    ("5a", "~/.config/opencode/skills/poe-gear-finder/SKILL.md", read("SKILL.md")),
    ("5b", "~/.config/opencode/skills/poe-gear-finder/reference/trade-api.md", read("reference/trade-api.md")),
    ("5c", "~/.config/opencode/skills/poe-gear-finder/reference/pob-sim.md", read("reference/pob-sim.md")),
]

block = ["STEP 5 — write the skill (3 files, exact content):", ""]
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
