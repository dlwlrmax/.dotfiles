#!/usr/bin/env bash
# Toggle focus: Stremio <-> previous window
# Uses address file to avoid Hyprland's unreliable focus history

STREMIO_CLASS="com.stremio.Stremio"
PREV_FILE="/tmp/stremio-prev-window"

if hyprctl activewindow | grep -q "class: $STREMIO_CLASS"; then
  # Stremio is focused → go back to saved previous window
  if [ -f "$PREV_FILE" ]; then
    prev_addr=$(cat "$PREV_FILE")
    rm -f "$PREV_FILE"
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$prev_addr\" })"
  fi
else
  # Save current window address before switching
  hyprctl activewindow -j | jq -r '.address' > "$PREV_FILE"
  hyprctl dispatch 'hl.dsp.focus({ window = "class:com.stremio.Stremio" })'
fi
