#!/bin/bash
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
LOCATION_ENCODED="${LOCATION// /%20}"

geo=$(curl -s --max-time 5 "https://geocoding-api.open-meteo.com/v1/search?name=${LOCATION_ENCODED}&count=1&language=en&format=json")
lat=$(echo "$geo" | jq -r '.results[0].latitude // empty')
lon=$(echo "$geo" | jq -r '.results[0].longitude // empty')

if [[ -z "$lat" ]]; then
    echo "󰅛 --"
    exit 0
fi

data=$(curl -s --max-time 5 "https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,weather_code&timezone=auto")
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
