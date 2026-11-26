#!/bin/bash
# Tests for scripts/stow-configs.sh (the settings panel's "Stow configs" fixer).
# Everything runs against a throwaway HOME and a fake DOTFILES_DIR holding only
# the packages under test, so no real config is ever touched.  Manifest rows for
# packages that are absent from the fake dotfiles are expected to fail loudly;
# the tests assert only on the rows under test.   Usage: tests/stow-configs.sh
# (or: tests/run.sh)

here="$(cd "$(dirname "$0")" && pwd)"
scripts="$here/../scripts"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export HOME="$work/home"
export DOTFILES_DIR="$work/dotfiles"

mkdir -p "$HOME/.cache"

# Fake dotfiles: two packages matching real manifest rows.
mkdir -p "$DOTFILES_DIR/swaync/.config/swaync" "$DOTFILES_DIR/fcitx5/.config/fcitx5"
printf '{}\n' > "$DOTFILES_DIR/swaync/.config/swaync/config.json"
printf 'repo config\n' > "$DOTFILES_DIR/fcitx5/.config/fcitx5/config"
printf 'repo profile\n' > "$DOTFILES_DIR/fcitx5/.config/fcitx5/profile"

# Local state: a stray real fcitx5 copy (stale, must lose to the repo) and no
# swaync config at all (missing, must be stowed).
mkdir -p "$HOME/.config/fcitx5"
printf 'local config\n' > "$HOME/.config/fcitx5/config"
printf 'local profile\n' > "$HOME/.config/fcitx5/profile"

passed=0; failed=0
ok() { passed=$((passed + 1)); echo "  ok   $1"; }
bad() { failed=$((failed + 1)); echo "  FAIL $1"; }
check() { local name="$1"; shift; if "$@"; then ok "$name"; else bad "$name"; fi; }

list_rows() { bash "$scripts/check-configs.sh" --list 2>/dev/null; }

echo "stow-configs.sh"

# ── dry-run changes nothing ──
out="$(bash "$scripts/stow-configs.sh" --dry-run 2>/dev/null)"
check "dry-run announces both stows" bash -c 'grep -q "stow swaync" <<< "$1" && grep -q "stow fcitx5" <<< "$1"' _ "$out"
check "dry-run announces backing up the stray config" grep -q "backed up ~/.config/fcitx5/config" <<< "$out"
check "dry-run leaves the stray file in place" test -f "$HOME/.config/fcitx5/config" -a ! -L "$HOME/.config/fcitx5/config"
check "dry-run creates no swaync link" test ! -e "$HOME/.config/swaync"

# ── real run ──
out="$(bash "$scripts/stow-configs.sh" 2>/dev/null)"
check "stows swaync as a dir symlink into the repo" bash -c '[ -L "$1/.config/swaync" ] && [ "$(readlink -f "$1/.config/swaync/config.json")" = "$2/swaync/.config/swaync/config.json" ]' _ "$HOME" "$DOTFILES_DIR"
check "stray fcitx5 config replaced by a repo symlink" bash -c '[ -L "$1/.config/fcitx5/config" ] && [ "$(readlink -f "$1/.config/fcitx5/config")" = "$2/fcitx5/.config/fcitx5/config" ]' _ "$HOME" "$DOTFILES_DIR"
check "repo copy wins over the stray copy" bash -c 'grep -q "repo config" "$1/.config/fcitx5/config" && grep -q "repo profile" "$1/.config/fcitx5/profile"' _ "$HOME"
check "stray copies are kept in the backup dir" bash -c 'grep -rq "local config" "$1/.cache/dotfiles-stow-backup/" && grep -rq "local profile" "$1/.cache/dotfiles-stow-backup/"' _ "$HOME"
check "the rows under test pass the checker now" bash -c '! list="$(bash "$2/check-configs.sh" --list 2>/dev/null)"; grep -v "no package" <<< "$list" | grep -qvE "swaync|fcitx5"' _ "$HOME" "$scripts"

# ── second run is a no-op, nothing new backed up ──
before="$(find "$HOME/.cache/dotfiles-stow-backup" -type f | wc -l)"
out="$(bash "$scripts/stow-configs.sh" 2>/dev/null)"
after="$(find "$HOME/.cache/dotfiles-stow-backup" -type f | wc -l)"
check "second run backs nothing up" test "$before" -eq "$after"
check "second run does not error on the packages under test" bash -c 'grep -q "stow swaync" <<< "$1" || ! grep -q "error: stow swaync failed" <<< "$1"; ! grep -q "backed up" <<< "$1"' _ "$out"

echo
if [ "$failed" -eq 0 ]; then echo "all $passed checks passed"; exit 0; fi
echo "$failed of $((passed + failed)) checks failed"; exit 1
