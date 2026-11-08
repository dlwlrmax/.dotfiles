#!/bin/bash
# List all battery devices from /sys/class/power_supply as JSON
# Output: {"devices": [{"name":"...", "capacity":N, "capacity_level":"...", "status":"...", "model":"...", "manufacturer":"..."}, ...]}
#
# One physical device can show up more than once (e.g. a Logitech mouse via its
# wireless receiver and via the USB cable while charging). Entries sharing a
# serial number are collapsed into one, preferring the node that is online and
# reports a known status.

esc() { local s="${1//\\/\\\\}"; s="${s//\"/\\\"}"; printf '%s' "$s"; }

declare -A best_json best_score
order=()

for d in /sys/class/power_supply/*/; do
    if [ ! -f "$d/type" ] || ! grep -q "Battery" "$d/type" 2>/dev/null; then
        continue
    fi

    name=$(basename "$d")
    cap="null"
    cap_level="null"
    status="Unknown"
    model=""
    mfr=""
    serial=""
    online=""

    [ -f "$d/capacity" ] && cap=$(cat "$d/capacity" 2>/dev/null || echo null)
    [ -f "$d/capacity_level" ] && cap_level="\"$(cat "$d/capacity_level" 2>/dev/null || echo Unknown)\""
    [ -f "$d/status" ] && status=$(cat "$d/status" 2>/dev/null || echo Unknown)
    [ -f "$d/model_name" ] && model=$(cat "$d/model_name" 2>/dev/null)
    [ -f "$d/manufacturer" ] && mfr=$(cat "$d/manufacturer" 2>/dev/null)
    [ -f "$d/serial_number" ] && serial=$(cat "$d/serial_number" 2>/dev/null)
    [ -f "$d/online" ] && online=$(cat "$d/online" 2>/dev/null)
    [ -z "$cap" ] && cap="null"

    model=$(esc "$model"); mfr=$(esc "$mfr"); name=$(esc "$name"); status=$(esc "$status")

    json="{\"name\":\"$name\",\"capacity\":$cap,\"capacity_level\":$cap_level,\"status\":\"$status\""
    [ -n "$model" ] && json+=",\"model\":\"$model\""
    [ -n "$mfr" ] && json+=",\"manufacturer\":\"$mfr\""
    json+='}'

    # dedupe key: serial when present, else the sysfs name (always unique)
    key="${serial:-name:$name}"
    score=0
    [ "$online" != "0" ] && score=$((score + 2))
    [ "$status" != "Unknown" ] && score=$((score + 1))

    if [ -z "${best_json[$key]+x}" ]; then
        order+=("$key")
        best_json[$key]=$json
        best_score[$key]=$score
    elif [ "$score" -gt "${best_score[$key]}" ]; then
        best_json[$key]=$json
        best_score[$key]=$score
    fi
done

out='{"devices":['
first=true
for key in "${order[@]}"; do
    [ "$first" = true ] && first=false || out+=','
    out+=${best_json[$key]}
done
echo "$out]}"
