#!/bin/bash
# Combined CPU + RAM + Swap stats, outputs JSON once
# Replaces separate cpu-usage.sh + mem-usage.sh forks

set -euo pipefail

# --- CPU ---
CACHE_FILE="/tmp/quickshell-cpu-cache"

read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
curr_idle=$((idle + iowait))
curr_total=$((user + nice + system + idle + iowait + irq + softirq + steal))

if [ -f "$CACHE_FILE" ]; then
    read -r prev_idle prev_total < "$CACHE_FILE"
    delta_idle=$((curr_idle - prev_idle))
    delta_total=$((curr_total - prev_total))
    if [ "$delta_total" -gt 0 ]; then
        cpu_usage=$((100 * (delta_total - delta_idle) / delta_total))
    else
        cpu_usage=0
    fi
else
    cpu_usage=0
fi
echo "$curr_idle $curr_total" > "$CACHE_FILE"

# --- RAM + Swap ---
read -r ram_total ram_used ram_avail swap_total swap_used <<< "$(free -k | awk '
  /^Mem:/  {ram_total=$2; ram_used=$3; ram_avail=$7}
  /^Swap:/ {swap_total=$2; swap_used=$3}
  END {print ram_total, ram_used, ram_avail, swap_total, swap_used}
')"

ram_usage=$((100 * ram_used / ram_total))

if [ "$swap_total" -gt 0 ]; then
    swap_usage=$((100 * swap_used / swap_total))
else
    swap_usage=0
fi

# --- JSON output ---
printf '{"cpu":%d,"ram":%d,"swap":%d}\n' "$cpu_usage" "$ram_usage" "$swap_usage"
