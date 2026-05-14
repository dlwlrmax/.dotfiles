#!/bin/bash
# Volume status for Quickshell
# Outputs: VOLUME% MUTE(true/false)

sink_info=$(pactl list sinks | grep -A 10 "Name: $(pactl info | grep 'Default Sink' | cut -d: -f2 | xargs)" 2>/dev/null)

if [ -z "$sink_info" ]; then
    echo "0 false"
    exit 0
fi

volume=$(echo "$sink_info" | grep "Volume:" | head -1 | grep -oP '\d+%' | head -1 | tr -d '%')
mute=$(echo "$sink_info" | grep "Mute:" | head -1 | awk '{print $2}')

if [ -z "$volume" ]; then
    volume=0
fi

if [ "$mute" = "yes" ]; then
    echo "$volume true"
else
    echo "$volume false"
fi
