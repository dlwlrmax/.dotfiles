#!/usr/bin/env bash
# Cycle focus: current -> Stremio -> mpv -> previous window
# Uses address file to avoid Hyprland's unreliable focus history
# NOTE: hyprctl dispatch takes Lua here: hl.dsp.focus({ window = ... })
# Native `focuswindow class:…` syntax does NOT work in this build.

STREMIO_CLASS="com.stremio.Stremio"
MPV_CLASS="mpv"
PREV_FILE="/tmp/stremio-prev-window"

if hyprctl activewindow | grep -q "class: $STREMIO_CLASS"; then
  # Stremio is focused → go to mpv if running, else back to saved previous window
  if hyprctl clients -j | jq -e 'any(.[]; .class=="mpv")' > /dev/null; then
    hyprctl dispatch 'hl.dsp.focus({ window = "class:mpv" })'
  elif [ -f "$PREV_FILE" ]; then
    prev_addr=$(cat "$PREV_FILE")
    rm -f "$PREV_FILE"
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$prev_addr\" })"
  fi
elif hyprctl activewindow | grep -q "class: $MPV_CLASS"; then
  # mpv is focused → go back to saved previous window
  if [ -f "$PREV_FILE" ]; then
    prev_addr=$(cat "$PREV_FILE")
    rm -f "$PREV_FILE"
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$prev_addr\" })"
  fi
else
  # Normal window → jump to Stremio if running, else mpv if running
  hyprctl activewindow -j | jq -r '.address' > "$PREV_FILE"
  if hyprctl clients -j | jq -e 'any(.[]; .class=="com.stremio.Stremio")' > /dev/null; then
    hyprctl dispatch 'hl.dsp.focus({ window = "class:com.stremio.Stremio" })'
  elif hyprctl clients -j | jq -e 'any(.[]; .class=="mpv")' > /dev/null; then
    hyprctl dispatch 'hl.dsp.focus({ window = "class:mpv" })'
  else
    rm -f "$PREV_FILE"
  fi
fi
