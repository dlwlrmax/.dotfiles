#!/bin/bash
# Calculate Intel GPU usage from RC6 residency + current freq
# Uses delta of rc6_residency_ms — no special perms needed

# Find Intel GPU (card0 or card1 or card2)
for card in 0 1 2; do
    GT="/sys/class/drm/card${card}/gt/gt0"
    [ -f "$GT/rc6_residency_ms" ] && break
    GT=""
done
if [ -z "$GT" ]; then echo "0 0"; exit 0; fi

RC6="$GT/rc6_residency_ms"
FREQ="$GT/rps_act_freq_mhz"

r1=$(cat "$RC6" 2>/dev/null) || r1=0
f1=$(cat "$FREQ" 2>/dev/null) || f1=0
sleep 0.5
r2=$(cat "$RC6" 2>/dev/null) || r2=0
f2=$(cat "$FREQ" 2>/dev/null) || f2=0

delta_rc6=$((r2 - r1))
delta_wall=500  # 0.5s in ms

if [ "$delta_wall" -gt 0 ] && [ "$delta_rc6" -le "$delta_wall" ] && [ "$delta_rc6" -ge 0 ]; then
    busy=$(( 100 * (delta_wall - delta_rc6) / delta_wall ))
else
    busy=0
fi

freq=$(( (f1 + f2) / 2 ))

echo "$busy $freq"
