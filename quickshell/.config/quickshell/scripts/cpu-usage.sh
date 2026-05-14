#!/bin/bash
# Calculate CPU usage percentage from /proc/stat

read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
prev_idle=$((idle + iowait))
prev_total=$((user + nice + system + idle + iowait + irq + softirq + steal))

sleep 1

read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
curr_idle=$((idle + iowait))
curr_total=$((user + nice + system + idle + iowait + irq + softirq + steal))

delta_idle=$((curr_idle - prev_idle))
delta_total=$((curr_total - prev_total))

if [ "$delta_total" -gt 0 ]; then
    usage=$((100 * (delta_total - delta_idle) / delta_total))
    echo "$usage"
else
    echo "0"
fi
