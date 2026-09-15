#!/bin/bash
# Notify about audio sink switch: audio-notify.sh <sink-name>
# Goes through org.freedesktop.Notifications → quickshell/swaync popup.
set -u
sink="${1:-}"
[ -z "$sink" ] && exit 0
desc=$(pactl list sinks 2>/dev/null | awk -v s="$sink" '
    $1 == "Name:" && $2 == s { found = 1; next }
    found && $1 == "Description:" { sub(/^[^:]+:[ \t]*/, ""); print; exit }
')
[ -z "$desc" ] && desc="$sink"
if command -v notify-send >/dev/null 2>&1; then
    notify-send -a "quickshell" -i "audio-speakers" "Audio Output" "$desc"
fi
