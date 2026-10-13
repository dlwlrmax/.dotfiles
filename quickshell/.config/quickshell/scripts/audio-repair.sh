#!/bin/bash
# Re-kick audio routing when streams play silently (EasyEffects chain stalled).
# Same effect as manually switching device back and forth / toggling EE.
# Invoked from VolumePanel repair button.
set -u

if pgrep -x easyeffects >/dev/null; then
    # Route every stream through EasyEffects' virtual sink
    while read -r idx; do
        [ -n "$idx" ] && pactl move-sink-input "$idx" easyeffects_sink 2>/dev/null
    done < <(pactl list short sink-inputs 2>/dev/null | awk '{print $1}')
    # Double toggle rebuilds EE pipeline links, leaves bypass state unchanged
    easyeffects --bypass-toggle
    sleep 0.3
    easyeffects --bypass-toggle
fi

# Re-apply default sink so EE re-links its output to hardware
sink=$(pactl get-default-sink 2>/dev/null) || exit 0
[ "$sink" = "easyeffects_sink" ] && exit 0
pactl suspend-sink "$sink" 1 2>/dev/null
pactl suspend-sink "$sink" 0 2>/dev/null
pactl set-default-sink "$sink"
