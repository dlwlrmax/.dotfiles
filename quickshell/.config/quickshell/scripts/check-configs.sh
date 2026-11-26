#!/usr/bin/env bash
# Check the config files in deps/configs.list: each must exist, be a symlink
# into ~/.dotfiles (i.e. stowed, not a stray local copy), parse as YAML, and
# — when a dotted key column is given in the manifest — hold a non-empty value
# at that key.
#
# Usage:
#   check-configs.sh            print failing rows (path<TAB>kind<TAB>reason)
#   check-configs.sh --list     same output, same contract as
#                               check-deps.sh --list (consumed by HealthData.qml)
#
# Only failures are listed; a healthy machine prints nothing and exits 0.

set -uo pipefail

here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
manifest="$here/../deps/configs.list"
dotfiles="${DOTFILES_DIR:-$HOME/.dotfiles}"

have_yaml() { python3 -c 'import yaml' >/dev/null 2>&1; }

# yaml_nonempty FILE KEY -> exit 0 when FILE parses and KEY resolves non-empty
yaml_nonempty() {
  python3 - "$1" "$2" 2>/dev/null <<'PY'
import sys, yaml
with open(sys.argv[1]) as f:
    node = yaml.safe_load(f) or {}
for part in sys.argv[2].split("."):
    if not isinstance(node, dict) or part not in node:
        sys.exit(1)
    node = node[part]
sys.exit(0 if node not in (None, "", [], {}) else 1)
PY
}

bad_rows() {
  [ -r "$manifest" ] || { echo "check-configs: no manifest at $manifest" >&2; return 1; }
  local path kind desc key file target reason
  while IFS=$'\t' read -r path kind desc key; do
    [[ -z "$path" || "$path" == \#* ]] && continue
    file="$HOME/$path"
    reason=""
    if [ ! -e "$file" ]; then
      reason="missing"
    else
      # Accept file-level symlinks AND files reached through a stowed
      # directory symlink (~/.config/lazygit -> ~/.dotfiles/...): what matters
      # is that the resolved path lands inside the dotfiles repo.
      target="$(readlink -f "$file" 2>/dev/null || true)"
      case "$target" in
        "$dotfiles"/*) ;;
        *) reason="not stowed (resolved path is not inside $dotfiles)" ;;
      esac
      if [ -z "$reason" ] && [ -n "$key" ]; then
        if ! have_yaml; then
          reason="cannot verify (python-yaml missing)"
        elif ! yaml_nonempty "$file" "$key"; then
          reason="YAML parse failed or key '$key' missing/empty"
        fi
      fi
    fi
    [ -n "$reason" ] && printf '%s\t%s\t%s\n' "$path" "${kind:-optional}" "$reason"
  done < "$manifest"
  return 0
}

case "${1:-}" in
  --list|"") bad_rows; exit $? ;;
  *) echo "usage: check-configs.sh [--list]" >&2; exit 2 ;;
esac
