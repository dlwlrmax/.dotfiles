#!/bin/bash
# Get current layout and window state
current_layout=$(hyprctl getoption general:layout | grep -oP '(?<=str: ).*')
active_window=$(hyprctl activewindow -j 2>/dev/null)

if [ -z "$active_window" ]; then
    # No active window, default to layout name
    status="$current_layout"
    icon=""
else
    is_floating=$(echo "$active_window" | jq -r '.floating')
    is_fullscreen=$(echo "$active_window" | jq -r '.fullscreen')

    if [ "$is_floating" = "true" ]; then
        status="Floating"
        icon=""
    elif [ "$is_fullscreen" = "true" ]; then
        status="Fullscreen"
        icon=""
    else
        status="$current_layout"
        icon=""
    fi
fi

# Output JSON for Waybar
echo "{\"text\":\"$icon $status\", \"tooltip\":\"Layout: $current_layout\"}"
