#!/bin/bash
# Calculate GPU usage — supports Intel (RC6 residency) and AMD (gpu_busy_percent)
# Output: BUSY_PCT FREQ_MHZ

# ── Intel GPU: use RC6 residency delta ──────────────────────────
for card in 0 1 2; do
    GT="/sys/class/drm/card${card}/gt/gt0"
    if [ -f "$GT/rc6_residency_ms" ]; then
        RC6="$GT/rc6_residency_ms"
        FREQ="$GT/rps_act_freq_mhz"
        r1=$(cat "$RC6" 2>/dev/null) || r1=0
        f1=$(cat "$FREQ" 2>/dev/null) || f1=0
        sleep 0.5
        r2=$(cat "$RC6" 2>/dev/null) || r2=0
        f2=$(cat "$FREQ" 2>/dev/null) || f2=0
        delta_rc6=$((r2 - r1))
        delta_wall=500
        if [ "$delta_wall" -gt 0 ] && [ "$delta_rc6" -le "$delta_wall" ] && [ "$delta_rc6" -ge 0 ]; then
            busy=$(( 100 * (delta_wall - delta_rc6) / delta_wall ))
        else
            busy=0
        fi
        freq=$(( (f1 + f2) / 2 ))
        echo "$busy $freq"
        exit 0
    fi
done

# ── AMD GPU: use gpu_busy_percent ───────────────────────────────
for card in 0 1 2; do
    DEV="/sys/class/drm/card${card}/device"
    BUSY_FILE="$DEV/gpu_busy_percent"
    if [ -f "$BUSY_FILE" ]; then
        busy=$(cat "$BUSY_FILE" 2>/dev/null) || busy=0
        # Try to read frequency from hwmon or pp_dpm_sclk
        freq=0
        for hwmon in "$DEV"/hwmon/hwmon*; do
            if [ -f "$hwmon/freq1_input" ]; then
                # freq1_input is in Hz, convert to MHz
                freq_raw=$(cat "$hwmon/freq1_input" 2>/dev/null) || freq_raw=0
                freq=$(( freq_raw / 1000000 ))
                break
            fi
        done
        echo "$busy $freq"
        exit 0
    fi
done

# ── No supported GPU found ──────────────────────────────────────
echo "0 0"
