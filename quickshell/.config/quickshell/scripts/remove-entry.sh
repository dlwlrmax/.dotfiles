#!/bin/bash
# Remove a launcher entry the user owns (the launcher's right-click "Remove from
# launcher", for entries that don't bring their own remove action).
#   remove-entry.sh <id>   move ~/.local/share/applications/<id>.desktop to the trash.
# Only the entry goes: the program it starts is left alone. Symlinked entries and
# entries that only exist system-wide are refused.
# When an installed (system or flatpak) entry has the same id, it would take the
# removed one's place, so a copy of it marked NoDisplay is left behind instead:
# gone from the launcher, still usable for opening files. Delete that copy to get
# the installed entry back.

set -euo pipefail

notify() { notify-send -a Launcher "$@" 2>/dev/null || true; }
fail() { notify -u critical -i dialog-error "Launcher" "$1"; echo "$1" >&2; exit 1; }

id="${1:?usage: remove-entry.sh <id>}"
[[ "$id" != */* ]] || fail "not an entry id: $id"
entry="${XDG_DATA_HOME:-$HOME/.local/share}/applications/$id.desktop"
[[ -f "$entry" && ! -L "$entry" ]] || fail "$id is not an entry of yours"

name="$(sed -n 's/^Name=//p' "$entry" | head -n1)"

twin=""
IFS=':' read -ra dirs <<< "$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
for d in "${dirs[@]}"; do
  cand="${d%/}/applications/$id.desktop"
  if [[ -f "$cand" && "$(realpath "$cand")" != "$(realpath "$entry")" ]]; then twin="$cand"; break; fi
done

gio trash -- "$entry" 2>/dev/null || rm -f -- "$entry"

if [[ -n "$twin" ]]; then
  awk '
    /^\[/ { main = ($0 == "[Desktop Entry]"); print; if (main) print "NoDisplay=true"; next }
    main && /^NoDisplay=/ { next }
    { print }
  ' "$twin" > "$entry"
  notify -i user-trash "Hidden from launcher" "${name:-$id}"$'\n'"your entry is in the trash; $entry now hides the installed one"
else
  notify -i user-trash "Removed from launcher" "${name:-$id}"$'\n'"the entry is in the trash"
fi
