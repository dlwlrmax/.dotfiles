#!/bin/bash
# Output RAM usage % and Swap usage % on separate lines

read -r ram_total ram_used ram_avail swap_total swap_used <<< "$(free -k | awk '
  /^Mem:/  {ram_total=$2; ram_used=$3; ram_avail=$7}
  /^Swap:/ {swap_total=$2; swap_used=$3}
  END {print ram_total, ram_used, ram_avail, swap_total, swap_used}
')"

ram_pct=$((100 * ram_used / ram_total))
echo "$ram_pct"

if [ "$swap_total" -gt 0 ]; then
    swap_pct=$((100 * swap_used / swap_total))
    echo "$swap_pct"
else
    echo "0"
fi
