#!/bin/bash
# List all battery devices from /sys/class/power_supply as JSON
# Output: {"devices": [{"name":"...", "capacity":N, "capacity_level":"...", "status":"...", "model":"...", "manufacturer":"..."}, ...]}

echo -n '{"devices":['
first=true
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

    [ -f "$d/capacity" ] && cap=$(cat "$d/capacity" 2>/dev/null || echo null)
    [ -f "$d/capacity_level" ] && cap_level="\"$(cat "$d/capacity_level" 2>/dev/null || echo Unknown)\""
    [ -f "$d/status" ] && status=$(cat "$d/status" 2>/dev/null || echo Unknown)
    [ -f "$d/model_name" ] && model=$(cat "$d/model_name" 2>/dev/null)
    [ -f "$d/manufacturer" ] && mfr=$(cat "$d/manufacturer" 2>/dev/null)

    [ "$first" = true ] && first=false || echo -n ','

    echo -n "{\"name\":\"$name\",\"capacity\":$cap,\"capacity_level\":$cap_level,\"status\":\"$status\""
    [ -n "$model" ] && echo -n ",\"model\":\"$model\""
    [ -n "$mfr" ] && echo -n ",\"manufacturer\":\"$mfr\""
    echo -n '}'
done
echo ']}'
