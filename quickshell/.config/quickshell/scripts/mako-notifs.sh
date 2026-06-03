#!/bin/bash
# Fetch mako notifications as JSON for Quickshell
# Outputs: {"count": N, "dnd": true/false, "active": [...], "history": [...]}

CACHE_DIR="$HOME/.cache/quickshell"
MAX_CLEARED_FILE="$CACHE_DIR/max-cleared-id"
TIMES_CACHE="$CACHE_DIR/notif-times.json"

max_cleared=0
[ -f "$MAX_CLEARED_FILE" ] && read -r max_cleared < "$MAX_CLEARED_FILE"

NOW=$(date +%s)
[ -f "$TIMES_CACHE" ] || echo '{}' > "$TIMES_CACHE"
TIMES_DATA=$(cat "$TIMES_CACHE")

active=$(makoctl list -j 2>/dev/null || echo '[]')

# Single jq: get active count + max id in one pass
read -r active_count max_active_id <<< "$(echo "$active" | jq -r '[length, (map(.id) | max // 0)] | @tsv')"

# Detect mako ID reset (e.g., after restart/reboot)
# Only reset when active notifs exist with IDs <= max_cleared.
# After "Clear All" dismisses everything, active_count=0 → no reset.
if [ "$active_count" -gt 0 ] && [ "$max_active_id" -le "$max_cleared" ] 2>/dev/null; then
    max_cleared=0
    echo 0 > "$MAX_CLEARED_FILE"
fi

history=$(makoctl history -j 2>/dev/null | jq --argjson max "$max_cleared" '[.[] | select(.id > $max)]' || echo '[]')

# DND check
dnd=false
makoctl mode 2>/dev/null | grep -qw "dnd" && dnd=true

# Single jq: annotate times + build output + persist cache
echo "$active" "$history" | jq -c -s --argjson times "$TIMES_DATA" --argjson now "$NOW" --argjson dnd $dnd '
  def annotate: map(.time = (if $times[.id | tostring] then $times[.id | tostring] else $now end));
  {
    count: (.[0] | length) + (.[1] | length),
    dnd: $dnd,
    active: (.[0] | annotate),
    history: (.[1] | annotate)
  }
'

# Persist timestamps — use cached time for known IDs, $now for new ones
echo "$TIMES_DATA" "$active" "$history" | jq -s --argjson now "$NOW" '
  .[0] as $cached |
  [.[1][], .[2][]] |
  map({(.id | tostring): ($cached[.id | tostring] // $now)}) |
  add as $new |
  $cached + $new
' > "$TIMES_CACHE"
