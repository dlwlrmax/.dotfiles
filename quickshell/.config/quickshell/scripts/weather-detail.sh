#!/bin/bash
LOCATION="${WEATHER_LOCATION:-Hanoi}"
LOCATION_ENCODED="${LOCATION// /%20}"

geo=$(curl -s --max-time 5 "https://geocoding-api.open-meteo.com/v1/search?name=${LOCATION_ENCODED}&count=1&language=en&format=json")
lat=$(echo "$geo" | jq -r '.results[0].latitude // empty')
lon=$(echo "$geo" | jq -r '.results[0].longitude // empty')
city=$(echo "$geo" | jq -r '.results[0].name // "'"$LOCATION"'"')
country=$(echo "$geo" | jq -r '.results[0].country // ""')

if [[ -z "$lat" ]]; then
    echo '{"icon":"","temp":"--","feelsLike":"--","humidity":"--","wind":"--","windDir":"","condition":"Unavailable","location":"","country":"","sunrise":"","sunset":"","pressure":"","uvIndex":"","visibility":"","cloudcover":"","precipMM":"","hourly":[],"daily":[]}'
    exit 0
fi

data=$(curl -s --max-time 10 "https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m,surface_pressure,cloud_cover,precipitation&daily=temperature_2m_max,temperature_2m_min,weather_code,sunrise,sunset,precipitation_sum,precipitation_probability_max&hourly=temperature_2m,weather_code,precipitation_probability,wind_speed_10m&forecast_hours=8&forecast_days=7&timezone=auto")

result=$(echo "$data" | jq -c --arg loc "$city" --arg cnt "$country" '
def wmoicon:
    if . == 0 then "🌞"
    elif . == 1 then "☀️"
    elif . == 2 then "⛅"
    elif . == 3 then "☁️"
    elif . == 45 or . == 48 then "🌫️"
    elif . == 51 or . == 53 or . == 55 then "🌦️"
    elif . == 56 or . == 57 then "🌧️"
    elif . == 61 then "🌧️"
    elif . == 63 or . == 65 then "☔"
    elif . == 66 or . == 67 then "🌧️"
    elif . == 71 then "🌨️"
    elif . == 73 or . == 75 or . == 77 then "❄️"
    elif . == 80 then "🌦️"
    elif . == 81 or . == 82 then "☔"
    elif . == 85 or . == 86 then "🌨️"
    elif . == 95 then "⛈️"
    elif . == 96 or . == 99 then "🌩️"
    else "🌡️" end;

def deg2dir:
    if . == null then ""
    elif . >= 337.5 or . < 22.5 then "N"
    elif . >= 22.5 and . < 67.5 then "NE"
    elif . >= 67.5 and . < 112.5 then "E"
    elif . >= 112.5 and . < 157.5 then "SE"
    elif . >= 157.5 and . < 202.5 then "S"
    elif . >= 202.5 and . < 247.5 then "SW"
    elif . >= 247.5 and . < 292.5 then "W"
    else "NW" end;

def fmtiso:
    if . == null then "" else .[11:16] end;

{
    icon: (.current.weather_code | wmoicon),
    temp: (.current.temperature_2m | tostring),
    feelsLike: (.current.apparent_temperature | tostring),
    humidity: (.current.relative_humidity_2m | tostring),
    wind: (.current.wind_speed_10m | tostring),
    windDir: (.current.wind_direction_10m | deg2dir),
    condition: (.current.weather_code | wmoicon),
    location: $loc,
    country: $cnt,
    sunrise: (.daily.sunrise[0] | fmtiso),
    sunset: (.daily.sunset[0] | fmtiso),
    pressure: (.current.surface_pressure | tostring),
    uvIndex: "",
    visibility: "",
    cloudcover: (.current.cloud_cover | tostring),
    precipMM: (.current.precipitation | tostring),
    hourly: [(.hourly as $h | $h.time | to_entries[] | {
        time: (.value[11:16]),
        temp: ($h.temperature_2m[.key] | tostring),
        chanceofrain: ($h.precipitation_probability[.key] // 0 | tostring),
        windspeed: ($h.wind_speed_10m[.key] | tostring)
    })],
    daily: [(.daily as $d | $d.time | to_entries[] | {
        date: .value,
        maxTemp: ($d.temperature_2m_max[.key] | tostring),
        minTemp: ($d.temperature_2m_min[.key] | tostring),
        condition: ($d.weather_code[.key] | wmoicon),
        chanceofrain: ($d.precipitation_probability_max[.key] // 0 | tostring)
    })]
}') || result='{"icon":"","temp":"--","feelsLike":"--","humidity":"--","wind":"--","windDir":"","condition":"Unavailable","location":"","country":"","sunrise":"","sunset":"","pressure":"","uvIndex":"","visibility":"","cloudcover":"","precipMM":"","hourly":[],"daily":[]}'
echo "$result"
