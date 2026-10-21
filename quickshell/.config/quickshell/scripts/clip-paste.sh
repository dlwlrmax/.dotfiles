#!/bin/bash
# Copy a clipboard-history entry (or literal text) and optionally paste it into the
# window that had focus before the picker opened.
#   clip-paste.sh copy  <history-id>   copy an entry
#   clip-paste.sh id    <history-id>   copy and paste it
#   clip-paste.sh text                 paste literal text from stdin
#   clip-paste.sh copytext             copy literal text from stdin
# An entry that is gone (deleted meanwhile) or empty leaves the clipboard untouched.
set -u
mode="${1:-}"
tmp="${XDG_RUNTIME_DIR:-/tmp}/quickshell-clip-paste.$$"
trap 'rm -f "$tmp"' EXIT

case "$mode" in
    copy|id)
        cliphist decode "${2:-0}" > "$tmp" 2>/dev/null
        [ -s "$tmp" ] || exit 1
        wl-copy < "$tmp" ;;
    text|copytext)
        cat > "$tmp"
        [ -s "$tmp" ] || exit 1
        wl-copy < "$tmp" ;;
    *) exit 1 ;;
esac

case "$mode" in
    copy|copytext) exit 0 ;;
esac

sleep 0.18   # let the picker release keyboard focus first
class=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // ""')
case "${class,,}" in
    *ghostty*|*kitty*|*alacritty*|*foot*|*wezterm*|*xterm*|*konsole*)
        mods="CTRL SHIFT" ;;
    *)  mods="CTRL" ;;
esac
hyprctl dispatch "hl.dsp.send_shortcut({ mods = \"$mods\", key = \"V\" })" >/dev/null 2>&1
