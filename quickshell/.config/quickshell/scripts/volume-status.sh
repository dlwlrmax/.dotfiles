#!/bin/bash
# Volume status for Quickshell
# Outputs: VOLUME% MUTE(true/false)
# Uses targeted pactl calls instead of listing all sinks

volume=$(pactl get-sink-volume @DEFAULT_SINK@ | head -1 | grep -oP '\d+%' | head -1 | tr -d '%')
mute=$(pactl get-sink-mute @DEFAULT_SINK@ | awk '{print $2}')

[ -z "$volume" ] && volume=0

if [ "$mute" = "yes" ]; then
    echo "$volume true"
else
    echo "$volume false"
fi
