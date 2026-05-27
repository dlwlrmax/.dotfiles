#!/bin/bash
LOCATION="${WEATHER_LOCATION:-Hanoi}"

LOCATION_ENCODED="${LOCATION// /%20}"

weather=$(curl -s --max-time 5 -H "User-Agent: curl" "https://wttr.in/${LOCATION_ENCODED}?format=%c|%t" 2>/dev/null)

if [[ -z "$weather" ]]; then
    echo "󰅛 --"
    exit 0
fi

IFS='|' read -r icon_raw temp_raw <<< "$weather"
icon=$(echo "$icon_raw" | xargs)
temp="${temp_raw#+}"

if [[ -z "$temp" ]]; then
    temp="--"
fi

echo "$icon $temp"
