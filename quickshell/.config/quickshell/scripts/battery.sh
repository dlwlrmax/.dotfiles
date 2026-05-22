#!/bin/bash
# Read battery info from /sys/class/power_supply
# Output: icon|level_text|status

battery=""
capacity=""
cap_level=""
status=""

for d in /sys/class/power_supply/*/; do
    if [ -f "$d/type" ] && grep -q "Battery" "$d/type" 2>/dev/null; then
        battery="$d"
        break
    fi
done

if [ -z "$battery" ]; then
    echo "||"
    exit 0
fi

[ -f "$battery/capacity" ] && capacity=$(cat "$battery/capacity" 2>/dev/null)
[ -f "$battery/capacity_level" ] && cap_level=$(cat "$battery/capacity_level" 2>/dev/null)
[ -f "$battery/status" ] && status=$(cat "$battery/status" 2>/dev/null)

# Determine icon based on capacity or capacity_level
if [ -n "$capacity" ]; then
    if [ "$status" = "Charging" ]; then
        icon="󰂄"
        text="${capacity}%"
    elif [ "$capacity" -ge 95 ]; then
        icon=""
        text="${capacity}%"
    elif [ "$capacity" -ge 75 ]; then
        icon=""
        text="${capacity}%"
    elif [ "$capacity" -ge 50 ]; then
        icon=""
        text="${capacity}%"
    elif [ "$capacity" -ge 25 ]; then
        icon=""
        text="${capacity}%"
    else
        icon=""
        text="${capacity}%"
    fi
elif [ -n "$cap_level" ]; then
    text="$cap_level"
    case "$cap_level" in
        Full)    icon="" ;;
        Normal)  icon="" ;;
        Low)     icon="" ;;
        Critical) icon="" ;;
        *)       icon="" ;;
    esac
    if [ "$status" = "Charging" ]; then
        icon="󰂄"
    fi
else
    icon=""
    text="?"
fi

echo "${icon}|${text}|${status}"
