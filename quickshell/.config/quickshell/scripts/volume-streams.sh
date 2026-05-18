#!/bin/bash
# PulseAudio volume streams for Quickshell VolumePanel
# Outputs JSON: { "sinks": [...], "streams": [...] }

default_sink=$(pactl info | grep "Default Sink:" | cut -d: -f2 | xargs)

echo -n '{"sinks":['
first=true

while IFS= read -r sink_name; do
    [ -z "$sink_name" ] && continue

    sink_data=$(pactl list sinks | awk -v sn="$sink_name" '
        BEGIN { found=0; desc=""; vol=0; mute="false" }
        $0 ~ "Name: " sn { found=1 }
        found && /Description:/ {
            sub(/^[[:space:]]*Description: /, "");
            desc=$0; gsub(/"/, "\\\"", desc)
        }
        found && /^[[:space:]]*Volume:/ {
            match($0, /[0-9]+%/);
            vol=substr($0, RSTART, RLENGTH-1)
        }
        found && /Mute:/ {
            mute=($2=="yes" ? "true" : "false")
        }
        found && /^$/ { print desc"|"vol"|"mute; exit }
    ')

    [ -z "$sink_data" ] && continue

    IFS='|' read -r desc vol mute <<< "$sink_data"
    is_default=$([ "$sink_name" = "$default_sink" ] && echo "true" || echo "false")

    [ "$first" = false ] && echo -n ','
    first=false
    echo -n "{\"name\":\"$sink_name\",\"description\":\"$desc\",\"volume\":${vol:-0},\"muted\":$mute,\"default\":$is_default}"
done < <(pactl list sinks short | awk '{print $2}')

echo -n '],"streams":['

first=true
while IFS='|' read -r idx app_name vol mute; do
    [ "$first" = false ] && echo -n ','
    first=false

    echo -n "{\"id\":$idx,\"name\":\"$app_name\",\"application\":\"$app_name\",\"volume\":${vol:-0},\"muted\":$mute}"
done < <(pactl list sink-inputs | awk '
    BEGIN { idx=""; app=""; vol=""; mute="false" }
    /Sink Input #/ { match($0, /[0-9]+/); idx=substr($0, RSTART, RLENGTH); app=""; vol=""; mute="false" }
    /application\.name = "/ || /media\.name = "/ {
        match($0, /"[^"]+"/);
        app=substr($0, RSTART+1, RLENGTH-2);
        gsub(/[\\"]/, "", app);
        gsub(/"/, "\\\"", app)
    }
    /Volume:/ { match($0, /[0-9]+%/); vol=substr($0, RSTART, RLENGTH-1) }
    /Mute:/ { mute=($2=="yes" ? "true" : "false") }
    /^$/ {
        if (idx != "" && app != "" && vol != "") print idx"|"app"|"vol"|"mute
        idx=""; app=""; vol=""; mute="false"
    }
    END {
        if (idx != "" && app != "" && vol != "") print idx"|"app"|"vol"|"mute
    }
')

echo ']}'
