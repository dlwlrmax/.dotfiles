#!/bin/bash
# Volume status for Quickshell
# Outputs: VOLUME% MUTE(true/false) DEFAULT_SINK(name, no spaces)
# Uses targeted pactl calls instead of listing all sinks

volume=$(pactl get-sink-volume @DEFAULT_SINK@ | head -1 | grep -oP '\d+%' | head -1 | tr -d '%')
mute=$(pactl get-sink-mute @DEFAULT_SINK@ | awk '{print $2}')
default_sink=$(pactl get-default-sink 2>/dev/null || true)

[ -z "$volume" ] && volume=0
[ -z "$default_sink" ] && default_sink="none"

if [ "$mute" = "yes" ]; then
    echo "$volume true $default_sink"
else
    echo "$volume false $default_sink"
fi
