#!/usr/bin/env bash
# Fix what check-configs.sh flags: stow the repo package that provides each
# failing path. Stray copies that would block stow (real files, or symlinks
# resolving outside the repo) are moved to a timestamped backup first, so the
# repo copy wins — local edits are never silently deleted.
#
# Usage:
#   stow-configs.sh             fix in place
#   stow-configs.sh --dry-run   print the plan, change nothing
#
# Prints one line per action, then re-runs the checker: exit 0 when every
# manifest row passes, 1 when rows remain.

set -uo pipefail

here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
checker="$here/check-configs.sh"
dotfiles="${DOTFILES_DIR:-$HOME/.dotfiles}"

DRY_RUN=0
case "${1:-}" in
  --dry-run) DRY_RUN=1 ;;
  "") ;;
  *) echo "usage: stow-configs.sh [--dry-run]" >&2; exit 2 ;;
esac

backup_dir="$HOME/.cache/dotfiles-stow-backup/$(date +%Y%m%d-%H%M%S)"
moved=0 stowed=0 failed=0

say() { printf '%s\n' "$*"; }

# resolve_ok FILE -> 0 when FILE resolves inside the repo (stowed already)
resolve_ok() {
  case "$(readlink -f "$1" 2>/dev/null)" in "$dotfiles"/*) return 0 ;; *) return 1 ;; esac
}

# pkg_for_path REL -> echoes the package whose tree provides REL
pkg_for_path() {
  local rel="$1" d
  for d in "$dotfiles"/*/; do
    if [ -e "${d}${rel}" ]; then basename "$d"; return 0; fi
  done
  return 1
}

# Collect the unique packages behind the failing manifest rows.
declare -A want=()
declare -a order=()
while IFS=$'\t' read -r path _kind _reason; do
  [ -z "$path" ] && continue
  rel="${path#./}"
  if pkg="$(pkg_for_path "$rel")"; then
    if [ -z "${want[$pkg]:-}" ]; then want[$pkg]=1; order+=("$pkg"); fi
  else
    say "error: no package in $dotfiles provides $path"
    failed=$((failed + 1))
  fi
done < <("$checker" --list)

# Back up anything under ~ that would collide with the package's files.
backup_blocking() {
  local pkg="$1" f rel target
  while IFS= read -r f; do
    rel="${f#./}"
    target="$HOME/$rel"
    if { [ -e "$target" ] || [ -L "$target" ]; } && ! resolve_ok "$target"; then
      if [ "$DRY_RUN" -eq 1 ]; then
        say "[dry-run] mv ~/$rel -> ~/${backup_dir#$HOME/}/$rel"
      else
        mkdir -p "$backup_dir/$(dirname "$rel")"
        mv "$target" "$backup_dir/$rel"
      fi
      say "backed up ~/$rel (was not stowed; repo copy wins)"
      moved=$((moved + 1))
    fi
  done < <(cd "$dotfiles/$pkg" && find . \( -type f -o -type l \) ! -name install.sh -print)
}

for pkg in "${order[@]}"; do
  backup_blocking "$pkg"
  if [ "$DRY_RUN" -eq 1 ]; then
    say "[dry-run] stow $pkg -> $HOME"
    stowed=$((stowed + 1))
    continue
  fi
  if stow --ignore='install\.sh' --dir "$dotfiles" --target "$HOME" "$pkg"; then
    say "stowed $pkg"
    stowed=$((stowed + 1))
  else
    say "error: stow $pkg failed" >&2
    failed=$((failed + 1))
  fi
done

[ "$moved" -gt 0 ] && say "moved $moved file(s) to ~/${backup_dir#$HOME/}"
say "$stowed package(s) stowed, $failed error(s)"

if [ "$DRY_RUN" -eq 1 ]; then
  say "[dry-run] nothing applied; run without --dry-run to fix"
  exit 0
fi

remaining="$("$checker" --list)"
if [ -z "$remaining" ] && [ "$failed" -eq 0 ]; then
  say "all manifest configs healthy"
  exit 0
fi
[ -n "$remaining" ] && say "still failing:" && say "$remaining"
exit 1
