#!/bin/bash
# PulseAudio volume streams for Quickshell VolumePanel
# Outputs JSON: { "sinks": [...], "streams": [...] }

default_sink=$(pactl info 2>/dev/null | grep "Default Sink:" | cut -d: -f2 | xargs)
sinks_dump=$(pactl list sinks 2>/dev/null)

json_escape() {
    # Escape \ then ", strip control chars for safe JSON strings
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\000-\037'
}

echo -n '{"sinks":['
first=true

while IFS= read -r sink_name; do
    [ -z "$sink_name" ] && continue

    sink_data=$(printf '%s\n' "$sinks_dump" | awk -v sn="$sink_name" '
        BEGIN { found=0; desc=""; vol=0; mute="false" }
        index($0, "Name: " sn) { found=1 }
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
        END { if (found) print desc"|"vol"|"mute }
    ')

    [ -z "$sink_data" ] && continue

    IFS='|' read -r desc vol mute <<< "$sink_data"
    is_default=$([ "$sink_name" = "$default_sink" ] && echo "true" || echo "false")

    [ "$first" = false ] && echo -n ','
    first=false
    esc_name=$(json_escape "$sink_name"); esc_desc=$(json_escape "$desc")
    echo -n "{\"name\":\"$esc_name\",\"description\":\"$esc_desc\",\"volume\":${vol:-0},\"muted\":$mute,\"default\":$is_default}"
# Physical sinks only: keep blocks with ALSA api or a hardware bus
# (pci/usb/bluetooth). Matches the filter in audio-cycle.sh.
done < <(printf '%s\n' "$sinks_dump" | awk '
    /^Sink #/ { if (name != "" && (api == "alsa" || bus != "")) print name; name = ""; api = ""; bus = "" }
    $1 == "Name:" { name = $2 }
    $1 == "device.api" { gsub(/"/, "", $3); api = $3 }
    $1 == "device.bus" { gsub(/"/, "", $3); bus = $3 }
    END { if (name != "" && (api == "alsa" || bus != "")) print name }
')

echo -n '],"streams":['

first=true
while IFS='|' read -r idx app_id app_name icon_name vol mute; do
    [ "$first" = false ] && echo -n ','
    first=false
    esc_app=$(json_escape "$app_name"); esc_app_id=$(json_escape "${app_id:-$app_name}"); esc_icon=$(json_escape "${icon_name:-$app_id}")
    echo -n "{\"id\":$idx,\"name\":\"$esc_app\",\"application\":\"$esc_app_id\",\"icon\":\"$esc_icon\",\"volume\":${vol:-0},\"muted\":$mute}"
done < <(pactl list sink-inputs | awk '
    BEGIN { idx=""; app_id=""; app_name=""; icon=""; vol=""; mute="false" }
    /Sink Input #/ { match($0, /[0-9]+/); idx=substr($0, RSTART, RLENGTH); app_id=""; app_name=""; icon=""; vol=""; mute="false" }
    /application\.name = "/ {
        match($0, /"[^"]+"/);
        app_id=substr($0, RSTART+1, RLENGTH-2);
        gsub(/[\\"]/, "", app_id);
        gsub(/"/, "\\\"", app_id)
    }
    /media\.name = "/ {
        match($0, /"[^"]+"/);
        app_name=substr($0, RSTART+1, RLENGTH-2);
        gsub(/[\\"]/, "", app_name);
        gsub(/"/, "\\\"", app_name)
    }
    /application\.icon_name = "/ {
        match($0, /"[^"]+"/);
        icon=substr($0, RSTART+1, RLENGTH-2);
        gsub(/[\\"]/, "", icon);
        gsub(/"/, "\\\"", icon)
    }
    /Volume:/ { match($0, /[0-9]+%/); vol=substr($0, RSTART, RLENGTH-1) }
    /Mute:/ { mute=($2=="yes" ? "true" : "false") }
    /^$/ {
        if (idx != "" && vol != "") {
            if (app_name == "" && app_id != "") app_name = app_id;
            print idx"|"app_id"|"app_name"|"icon"|"vol"|"mute
        }
        idx=""; app_id=""; app_name=""; icon=""; vol=""; mute="false"
    }
    END {
        if (idx != "" && vol != "") {
            if (app_name == "" && app_id != "") app_name = app_id;
            print idx"|"app_id"|"app_name"|"icon"|"vol"|"mute
        }
    }
')

echo ']}'
