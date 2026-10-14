#!/usr/bin/env bash
# Check the packages in deps/deps.list and, if any are missing, post a
# notification with an "Install" button that opens a terminal running the
# AUR helper (or pacman) for exactly the missing packages.
#
# Usage:
#   check-deps.sh            check; notify only if something is missing
#   check-deps.sh --verbose  also notify when everything is installed
#   check-deps.sh --list     print missing packages (pkg<TAB>kind<TAB>desc), no UI,
#                            including `setup` entries (install.sh uses this)
#   check-deps.sh --install pkg...   install in a terminal, then re-check

set -uo pipefail

here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
manifest="$here/../deps/deps.list"
ignore_file="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/deps-ignore"
valid='^[a-z0-9@._+-]+$'

missing_rows() {
  [ -r "$manifest" ] || { echo "check-deps: no manifest at $manifest" >&2; return 1; }
  local -A ignored=() kind=() desc=()
  local -a pkgs=()
  if [ -r "$ignore_file" ]; then
    while read -r p _; do [[ -n "$p" && "$p" != \#* ]] && ignored[$p]=1; done < "$ignore_file"
  fi
  while read -r p k d; do
    [[ -z "$p" || "$p" == \#* ]] && continue
    [[ "$p" =~ $valid ]] || continue
    [[ -n "${ignored[$p]:-}" ]] && continue
    pkgs+=("$p"); kind[$p]="$k"; desc[$p]="$d"
  done < "$manifest"
  [ ${#pkgs[@]} -eq 0 ] && return 0
  # pacman -T prints every unsatisfied dependency (provides are honoured);
  # exit 0 = all satisfied, 127 = some missing, anything else = pacman failed.
  local out rc m
  out="$(pacman -T "${pkgs[@]}" 2>/dev/null)"; rc=$?
  if [ $rc -ne 0 ] && [ $rc -ne 127 ]; then
    echo "check-deps: pacman -T failed (exit $rc)" >&2
    return 1
  fi
  while read -r m; do
    [ -n "$m" ] && printf '%s\t%s\t%s\n' "$m" "${kind[$m]:-optional}" "${desc[$m]:-}"
  done <<< "$out"
  return 0
}

install_in_terminal() {
  local p
  for p in "$@"; do [[ "$p" =~ $valid ]] || { echo "check-deps: bad package name: $p" >&2; exit 1; }; done
  local helper
  if command -v paru >/dev/null; then helper="paru -S --needed"
  elif command -v yay >/dev/null; then helper="yay -S --needed"
  else helper="sudo pacman -S --needed"; fi
  local self; self="$(readlink -f "$0")"
  # setsid -f: the re-check must outlive the terminal (closing it SIGHUPs its jobs).
  local cmd="$helper $*; echo; read -rp 'Done. Press Enter to close… '; setsid -f '$self' --verbose >/dev/null 2>&1"
  local term="${TERMINAL:-ghostty}"
  setsid -f "$term" -e bash -c "$cmd" >/dev/null 2>&1
}

case "${1:-}" in
  --list) missing_rows; exit $? ;;
  --install) shift; [ $# -gt 0 ] && install_in_terminal "$@"; exit 0 ;;
esac
verbose=0; [ "${1:-}" = "--verbose" ] && verbose=1

rows="$(missing_rows | awk -F'\t' '$2 != "setup"')" || exit 1
if [ -z "$rows" ]; then
  [ $verbose -eq 1 ] && notify-send -a "Dependencies" -i package-x-generic \
    "All dependencies installed" "Nothing missing from deps.list."
  exit 0
fi

pkgs=(); body=""; urgency=normal
while IFS=$'\t' read -r p k d; do
  [ -z "$p" ] || [ "$k" = setup ] && continue  # install.sh's job, not a runtime gap
  pkgs+=("$p")
  [ "$k" = "required" ] && urgency=critical
  body+="• $p — ${d:-$k}"$'\n'
done <<< "$rows"

title="Missing ${#pkgs[@]} package$([ ${#pkgs[@]} -gt 1 ] && echo s)"
[ "$urgency" = critical ] && title+=" (required)"

# --wait keeps notify-send alive until the button is pressed or the
# notification closes; critical ones stay on screen until handled.
action=$(notify-send -a "Dependencies" -i package-x-generic -u "$urgency" \
  -A install="Install" --wait "$title" "${body%$'\n'}" 2>/dev/null)

[ "$action" = install ] && install_in_terminal "${pkgs[@]}"
exit 0
