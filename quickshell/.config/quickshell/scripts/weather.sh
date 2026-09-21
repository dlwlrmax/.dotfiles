#!/bin/bash
# Bar weather: icon + temp for the panel widget.
# Resolve location: env var > config file > error
LOCATION="${WEATHER_LOCATION:-}"
if [[ -z "$LOCATION" ]] && [[ -f "$HOME/.config/quickshell/weather-location" ]]; then
    LOCATION=$(head -1 "$HOME/.config/quickshell/weather-location")
fi
if [[ -z "$LOCATION" ]]; then
    echo "󰅛 Set WEATHER_LOCATION or ~/.config/quickshell/weather-location" >&2
    echo "󰅛 --"
    exit 0
fi

source "$(dirname "$0")/weather-common.sh"
resolve_geo "$LOCATION" || { echo "󰅛 --"; exit 0; }

data=$(curl -s --max-time 5 "https://api.open-meteo.com/v1/forecast?latitude=${GEO_LAT}&longitude=${GEO_LON}&current=temperature_2m,weather_code&timezone=auto")
temp=$(echo "$data" | jq -r '(.current.temperature_2m // empty) | round')
code=$(echo "$data" | jq -r '.current.weather_code // empty')

if [[ -z "$temp" ]]; then
    echo "󰅛 --"
    exit 0
fi

case $code in
    0) icon="🌞" ;;
    1) icon="☀️" ;;
    2) icon="⛅" ;;
    3) icon="☁️" ;;
    45|48) icon="🌫️" ;;
    51|53|55) icon="🌦️" ;;
    56|57) icon="🌧️" ;;
    61) icon="🌧️" ;;
    63|65) icon="☔" ;;
    66|67) icon="🌧️" ;;
    71) icon="🌨️" ;;
    73|75|77) icon="❄️" ;;
    80) icon="🌦️" ;;
    81|82) icon="☔" ;;
    85|86) icon="🌨️" ;;
    95) icon="⛈️" ;;
    96|99) icon="🌩️" ;;
    *) icon="🌡️" ;;
esac

echo "$icon $temp"
