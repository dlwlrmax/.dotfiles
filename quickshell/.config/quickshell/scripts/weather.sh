#!/bin/bash
# Simple weather for Quickshell
# Uses wttr.in with minimal output

LOCATION="${WEATHER_LOCATION:-}"

weather=$(curl -s "https://wttr.in/${LOCATION}?format=%c+%t" 2>/dev/null | sed 's/+//' || echo "")

if [[ -z "$weather" ]]; then
    echo "󰅛 --"
    exit 0
fi

echo "$weather"
