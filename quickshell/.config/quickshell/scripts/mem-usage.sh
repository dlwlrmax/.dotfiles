#!/bin/bash
# Output RAM usage % and Swap usage % on separate lines

read -r _ total used _ avail _ < <(free | awk '/^Mem:/ {print $1, $2, $3, $4, $7}')
ram_pct=$((100 * used / total))

echo "$ram_pct"

read -r _ stotal sused _ < <(free | awk '/^Swap:/ {print $1, $2, $3}')
if [ "$stotal" -gt 0 ]; then
    swap_pct=$((100 * sused / stotal))
    echo "$swap_pct"
else
    echo "0"
fi
