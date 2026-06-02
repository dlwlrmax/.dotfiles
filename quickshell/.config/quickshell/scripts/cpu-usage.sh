#!/bin/bash
# Calculate CPU usage percentage from /proc/stat using cached delta
# No sleep needed — stores prev sample in cache, diffs on next call

CACHE_FILE="/tmp/quickshell-cpu-cache"

read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
curr_idle=$((idle + iowait))
curr_total=$((user + nice + system + idle + iowait + irq + softirq + steal))

if [ -f "$CACHE_FILE" ]; then
    read -r prev_idle prev_total < "$CACHE_FILE"
    delta_idle=$((curr_idle - prev_idle))
    delta_total=$((curr_total - prev_total))
    if [ "$delta_total" -gt 0 ]; then
        usage=$((100 * (delta_total - delta_idle) / delta_total))
    else
        usage=0
    fi
else
    usage=0
fi

# Write current values for next delta calc
echo "$curr_idle $curr_total" > "$CACHE_FILE"
echo "$usage"
