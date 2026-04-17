#!/bin/bash
# Weather module using wttrbar for waybar
# https://github.com/bjesus/wttrbar

set -e

# Check if wttrbar is installed, fallback to curl wttr.in if not
if command -v wttrbar &>/dev/null; then
    # Use wttrbar with custom options
    wttrbar --location "${WEATHER_LOCATION:-}" --hide-conditions
else
    # Fallback to curl wttr.in with JSON output
    LOCATION="${WEATHER_LOCATION:-}"
    curl -s "https://wttr.in/${LOCATION}?format=j1" 2>/dev/null | jq -r '
        .current_condition[0] as $c |
        {
            text: "\($c.weatherDesc[0].value) \($c.temp_C)°C",
            tooltip: "Weather: \($c.weatherDesc[0].value)\nTemperature: \($c.temp_C)°C\nFeels like: \($c.FeelsLikeC)°C\nHumidity: \($c.humidity)%\nWind: \($c.windspeedKmph) km/h",
            class: "weather"
        }'
fi
