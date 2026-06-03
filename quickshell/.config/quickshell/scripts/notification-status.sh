#!/bin/bash
# Notification status for Quickshell (mako)
# Outputs: COUNT DND(true/false)

CACHE_DIR="$HOME/.cache/quickshell"
MAX_CLEARED_FILE="$CACHE_DIR/max-cleared-id"

max_cleared=0
if [ -f "$MAX_CLEARED_FILE" ]; then
    max_cleared=$(cat "$MAX_CLEARED_FILE")
fi

# Count active + history notifications (history filtered by last clear)
if command -v makoctl &>/dev/null; then
    active=$(makoctl list -j 2>/dev/null || echo '[]')
    active_count=$(echo "$active" | jq -r 'length' 2>/dev/null || echo "0")
    history_count=$(makoctl history -j 2>/dev/null | jq -r --argjson max "$max_cleared" '[.[] | select(.id > $max)] | length' 2>/dev/null || echo "0")

    # Detect mako ID reset (e.g., after mako restart/reboot)
    # Only reset when active notifs exist with old IDs.
    # After "Clear All" dismisses everything, active_count=0 → no reset.
    if [ "$active_count" -gt 0 ] && [ "$history_count" -eq 0 ]; then
        max_active_id=$(echo "$active" | jq 'map(.id) | max // 0')
        if [ "$max_active_id" -le "$max_cleared" ] 2>/dev/null; then
            max_cleared=0
            echo 0 > "$MAX_CLEARED_FILE"
            history_count=$(makoctl history -j 2>/dev/null | jq -r --argjson max "$max_cleared" '[.[] | select(.id > $max)] | length' 2>/dev/null || echo "0")
        fi
    fi

    count=$((active_count + history_count))

    # Check if "dnd" mode is active
    dnd_modes=$(makoctl mode 2>/dev/null || echo "")
    if echo "$dnd_modes" | grep -qw "dnd"; then
        dnd="true"
    else
        dnd="false"
    fi
else
    count="0"
    dnd="false"
fi

echo "$count $dnd"
