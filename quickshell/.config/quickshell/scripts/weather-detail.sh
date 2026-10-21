#!/bin/bash
# Weather for the bar widget and the panel: one JSON document, numbers raw
# (the UI converts units). Open-Meteo, no API key.
#
# Location: $WEATHER_LOCATION > ~/.config/quickshell/weather-location. Either a
# place name ("Hanoi") or "lat,lon[,City[,Country]]" (written by the panel).
#
# Output: {"ok":true,"updated":<epoch>,"location":..,"current":{..},"hourly":[..],"daily":[..],"aqi":..}
#     or  {"ok":false,"error":"no-location"|"geocode"|"network","message":".."}

fail() { jq -cn --arg e "$1" --arg m "$2" '{ok:false,error:$e,message:$m}'; exit 0; }

LOCATION="${WEATHER_LOCATION:-}"
if [[ -z "$LOCATION" ]] && [[ -f "$HOME/.config/quickshell/weather-location" ]]; then
    LOCATION=$(head -1 "$HOME/.config/quickshell/weather-location")
fi
[[ -z "$LOCATION" ]] && fail no-location "Set a location in the weather panel"

source "$(dirname "$0")/weather-common.sh"
resolve_geo "$LOCATION" || fail geocode "Could not find \"$LOCATION\""

fetch() { curl -fsS --max-time 10 --retry 1 --retry-delay 1 "$1" 2>/dev/null; }

data=$(fetch "https://api.open-meteo.com/v1/forecast?latitude=${GEO_LAT}&longitude=${GEO_LON}&current=temperature_2m,apparent_temperature,relative_humidity_2m,is_day,weather_code,wind_speed_10m,wind_direction_10m,surface_pressure,cloud_cover,precipitation,uv_index,visibility&daily=temperature_2m_max,temperature_2m_min,weather_code,sunrise,sunset,precipitation_probability_max&hourly=temperature_2m,weather_code,precipitation_probability,wind_speed_10m,is_day&forecast_hours=12&forecast_days=7&timezone=auto") \
    || fail network "Weather service unreachable"

# Air quality is optional: a failure just drops the AQI badge.
air=$(fetch "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=${GEO_LAT}&longitude=${GEO_LON}&current=us_aqi,pm2_5&timezone=auto") || air='{}'

echo "$data" | jq -c --argjson air "${air:-{\}}" --arg loc "$GEO_CITY" --arg cnt "$GEO_COUNTRY" --argjson now "$(date +%s)" '
# code -> [description, kind, day glyph, night glyph]  (nf-weather)
def wmo($code; $day):
    ({
      "0":  ["Clear sky",            "clear",   "󰖙", "󰖔"],
      "1":  ["Mainly clear",         "clear",   "󰖙", "󰖔"],
      "2":  ["Partly cloudy",        "partly",  "󰖕", "󰼱"],
      "3":  ["Overcast",             "cloud",   "󰖐", "󰖐"],
      "45": ["Fog",                  "fog",     "󰖑", "󰖑"],
      "48": ["Freezing fog",         "fog",     "󰖑", "󰖑"],
      "51": ["Light drizzle",        "drizzle", "󰖗", "󰖗"],
      "53": ["Drizzle",              "drizzle", "󰖗", "󰖗"],
      "55": ["Heavy drizzle",        "drizzle", "󰖗", "󰖗"],
      "56": ["Freezing drizzle",     "snow",    "󰙿", "󰙿"],
      "57": ["Freezing drizzle",     "snow",    "󰙿", "󰙿"],
      "61": ["Light rain",           "rain",    "󰖗", "󰖗"],
      "63": ["Rain",                 "rain",    "󰖖", "󰖖"],
      "65": ["Heavy rain",           "rain",    "󰖖", "󰖖"],
      "66": ["Freezing rain",        "snow",    "󰙿", "󰙿"],
      "67": ["Freezing rain",        "snow",    "󰙿", "󰙿"],
      "71": ["Light snow",           "snow",    "󰖘", "󰖘"],
      "73": ["Snow",                 "snow",    "󰖘", "󰖘"],
      "75": ["Heavy snow",           "snow",    "󰖘", "󰖘"],
      "77": ["Snow grains",          "snow",    "󰖘", "󰖘"],
      "80": ["Light showers",        "rain",    "󰖗", "󰖗"],
      "81": ["Showers",              "rain",    "󰖗", "󰖗"],
      "82": ["Violent showers",      "rain",    "󰖖", "󰖖"],
      "85": ["Snow showers",         "snow",    "󰖘", "󰖘"],
      "86": ["Heavy snow showers",   "snow",    "󰖘", "󰖘"],
      "95": ["Thunderstorm",         "storm",   "󰙾", "󰙾"],
      "96": ["Thunderstorm, hail",   "storm",   "󰙾", "󰙾"],
      "99": ["Thunderstorm, hail",   "storm",   "󰙾", "󰙾"]
    }[($code | tostring)] // ["Unknown", "cloud", "󰖐", "󰖐"])
    | {desc: .[0], kind: .[1], icon: (if $day then .[2] else .[3] end)};

def deg2dir:
    if . == null then ""
    elif . >= 337.5 or . < 22.5 then "N"
    elif . < 67.5 then "NE"
    elif . < 112.5 then "E"
    elif . < 157.5 then "SE"
    elif . < 202.5 then "S"
    elif . < 247.5 then "SW"
    elif . < 292.5 then "W"
    else "NW" end;

def hm: if . == null then "" else .[11:16] end;
def r1: if . == null then null else (. * 10 | round / 10) end;

(.current.is_day == 1) as $day
| (.current.weather_code | wmo(.; $day)) as $w
| {
    ok: true,
    updated: $now,
    location: $loc,
    country: $cnt,
    current: {
        temp: (.current.temperature_2m | r1),
        feels: (.current.apparent_temperature | r1),
        humidity: .current.relative_humidity_2m,
        wind: (.current.wind_speed_10m | r1),
        windDir: (.current.wind_direction_10m | deg2dir),
        pressure: (.current.surface_pressure | round),
        cloud: .current.cloud_cover,
        precip: .current.precipitation,
        uv: (.current.uv_index | r1),
        visibilityKm: (if .current.visibility == null then null else (.current.visibility / 1000 | r1) end),
        isDay: $day,
        code: .current.weather_code,
        desc: $w.desc, kind: $w.kind, icon: $w.icon
    },
    sunrise: (.daily.sunrise[0] | hm),
    sunset: (.daily.sunset[0] | hm),
    aqi: ($air.current.us_aqi // null),
    pm25: ($air.current.pm2_5 // null | r1),
    hourly: [(.hourly as $h | $h.time | to_entries[] | . as $e
        | ($h.is_day[$e.key] == 1) as $d
        | ($h.weather_code[$e.key] | wmo(.; $d)) as $hw
        | {
            time: ($e.value | hm),
            temp: ($h.temperature_2m[$e.key] | r1),
            rain: ($h.precipitation_probability[$e.key] // 0),
            wind: ($h.wind_speed_10m[$e.key] | r1),
            isDay: $d, kind: $hw.kind, icon: $hw.icon
        })],
    daily: [(.daily as $d | $d.time | to_entries[] | . as $e
        | ($d.weather_code[$e.key] | wmo(.; true)) as $dw
        | {
            date: $e.value,
            max: ($d.temperature_2m_max[$e.key] | r1),
            min: ($d.temperature_2m_min[$e.key] | r1),
            rain: ($d.precipitation_probability_max[$e.key] // 0),
            kind: $dw.kind, icon: $dw.icon, desc: $dw.desc
        })]
}' || fail network "Unexpected response from the weather service"
