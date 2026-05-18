#!/bin/bash
# Fetch mako notifications as JSON for Quickshell
# Outputs: {"active": [...], "history": [...]}

CACHE_DIR="$HOME/.cache/quickshell"
MAX_CLEARED_FILE="$CACHE_DIR/max-cleared-id"

max_cleared=0
if [ -f "$MAX_CLEARED_FILE" ]; then
    max_cleared=$(cat "$MAX_CLEARED_FILE")
fi

active=$(makoctl list -j 2>/dev/null || echo '[]')

# Detect mako ID reset (e.g., after mako restart/reboot)
active_count=$(echo "$active" | jq 'length')
if [ "$active_count" -gt 0 ]; then
    max_active_id=$(echo "$active" | jq 'map(.id) | max // 0')
    if [ "$max_active_id" -le "$max_cleared" ]; then
        max_cleared=0
        echo 0 > "$MAX_CLEARED_FILE"
    fi
fi

history=$(makoctl history -j 2>/dev/null | jq --argjson max "$max_cleared" '[.[] | select(.id > $max)]' || echo '[]')

echo "{\"active\": $active, \"history\": $history}"
