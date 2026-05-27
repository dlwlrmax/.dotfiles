#!/bin/bash
LOCATION="${WEATHER_LOCATION:-Hanoi}"

LOCATION_ENCODED="${LOCATION// /%20}"

data=$(curl -s --max-time 10 -H "User-Agent: curl" "https://wttr.in/${LOCATION_ENCODED}?format=j1" 2>/dev/null || echo "")

if [[ -z "$data" ]]; then
    echo '{"icon":"","temp":"--","feelsLike":"--","humidity":"--","wind":"--","windDir":"","condition":"Unavailable","location":"","country":"","sunrise":"","sunset":"","hourly":[],"daily":[]}'
    exit 0
fi

echo "$data" | jq -c --arg loc "$LOCATION" '
def wticon:
    if . == 113 then "☀"
    elif . <= 116 then "⛅"
    elif . <= 122 then "☁"
    elif . == 143 or . == 248 or . == 260 then "🌫"
    elif . <= 185 then "🌦"
    elif . == 200 then "⛈"
    elif . <= 230 then "🌨"
    elif . <= 284 then "🌧"
    elif . <= 320 then "🌨"
    elif . <= 338 then "🌨"
    elif . == 350 then "🌨"
    elif . <= 359 then "🌦"
    elif . <= 377 then "🌨"
    elif . <= 395 then "⛈"
    else "🌡" end;

def fmthour: (. | tonumber? / 100 | floor | tostring | if length == 1 then "0" + . else . end) + ":00";

{
    icon: (.current_condition[0].weatherCode | tonumber | wticon),
    temp: .current_condition[0].temp_C,
    feelsLike: .current_condition[0].FeelsLikeC,
    humidity: .current_condition[0].humidity,
    wind: .current_condition[0].windspeedKmph,
    windDir: .current_condition[0].winddir16Point,
    condition: .current_condition[0].weatherDesc[0].value,
    location: ($loc),
    country: (.nearest_area[0].country[0].value // ""),
    sunrise: .weather[0].astronomy[0].sunrise,
    sunset: .weather[0].astronomy[0].sunset,
    hourly: [.weather[0].hourly[] | select((.time | tonumber?) % 300 == 0) | {
        time: (.time | fmthour),
        temp: .tempC,
        condition: .weatherDesc[0].value
    }],
    daily: [.weather[] | {
        date: .date,
        maxTemp: .maxtempC,
        minTemp: .mintempC,
        condition: .hourly[4].weatherDesc[0].value
    }]
}' 2>/dev/null || echo '{"icon":"","temp":"--","feelsLike":"--","humidity":"--","wind":"--","windDir":"","condition":"Unavailable","location":"","country":"","sunrise":"","sunset":"","hourly":[],"daily":[]}'
