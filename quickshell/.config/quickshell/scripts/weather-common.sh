#!/bin/bash
# Shared weather helpers: location resolution + cached geocoding + URI encoding.
# Source this, then call: resolve_geo "$LOCATION"
# On success sets: GEO_LAT GEO_LON GEO_CITY GEO_COUNTRY (empty on failure, returns 1).

resolve_geo() {
    local location="${1:-}"
    GEO_LAT=""; GEO_LON=""; GEO_CITY=""; GEO_COUNTRY=""
    [ -z "$location" ] && return 1

    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/weather"
    local cache_key
    cache_key=$(printf '%s' "$location" | sha256sum | cut -d' ' -f1)
    local cache_file="$cache_dir/geo-$cache_key"

    if [ -f "$cache_file" ]; then
        IFS='|' read -r GEO_LAT GEO_LON GEO_CITY GEO_COUNTRY < "$cache_file"
        [ -n "$GEO_LAT" ] && [ -n "$GEO_LON" ] && return 0
    fi

    local enc
    enc=$(jq -rn --arg v "$location" '$v|@uri')
    local geo
    geo=$(curl -s --max-time 5 "https://geocoding-api.open-meteo.com/v1/search?name=${enc}&count=1&language=en&format=json")

    GEO_LAT=$(echo "$geo" | jq -r '.results[0].latitude // empty')
    GEO_LON=$(echo "$geo" | jq -r '.results[0].longitude // empty')
    GEO_CITY=$(echo "$geo" | jq -r --arg loc "$location" '.results[0].name // $loc')
    GEO_COUNTRY=$(echo "$geo" | jq -r '.results[0].country // ""')

    if [ -n "$GEO_LAT" ] && [ -n "$GEO_LON" ]; then
        mkdir -p "$cache_dir"
        printf '%s|%s|%s|%s\n' "$GEO_LAT" "$GEO_LON" "$GEO_CITY" "$GEO_COUNTRY" > "$cache_file"
        return 0
    fi
    return 1
}
