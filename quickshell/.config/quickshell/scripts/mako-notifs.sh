#!/bin/bash
# Fetch mako notifications as JSON for Quickshell
# Outputs: {"count": N, "dnd": true/false, "active": [...], "history": [...]}

CACHE_DIR="$HOME/.cache/quickshell"
MAX_CLEARED_FILE="$CACHE_DIR/max-cleared-id"
TIMES_CACHE="$CACHE_DIR/notif-times.json"

max_cleared=0
if [ -f "$MAX_CLEARED_FILE" ]; then
    max_cleared=$(cat "$MAX_CLEARED_FILE")
fi

# ---- Timestamp tracking ----
NOW=$(date +%s)
[ -f "$TIMES_CACHE" ] || echo '{}' > "$TIMES_CACHE"
TIMES_DATA=$(cat "$TIMES_CACHE")

# Inject .time field (unix epoch) into each notification.
# Use cached time if known, else current time.
annotate_times() {
    echo "$1" | jq --argjson times "$TIMES_DATA" --argjson now "$NOW" '
        [.[] | .time = (if $times[.id | tostring] then $times[.id | tostring] else $now end)]
    '
}

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

# Annotate with timestamps
active=$(annotate_times "$active")
history=$(annotate_times "$history")

# Persist any newly discovered IDs to cache
# Merge existing + new times, keep earliest timestamp per ID
NEW_TIMES=$(echo "$active" "$history" | jq -s 'add | map({(.id|tostring): .time}) | add')
MERGED=$(echo "$TIMES_DATA" "$NEW_TIMES" | jq -s 'add')
echo "$MERGED" > "$TIMES_CACHE"

history_count=$(echo "$history" | jq 'length' 2>/dev/null || echo "0")
count=$((active_count + history_count))

dnd="false"
dnd_modes=$(makoctl mode 2>/dev/null || echo "")
if echo "$dnd_modes" | grep -qw "dnd"; then
    dnd="true"
fi

echo "{\"count\": $count, \"dnd\": $dnd, \"active\": $active, \"history\": $history}"
