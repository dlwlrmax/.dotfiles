#!/bin/bash
# Calculate GPU usage — supports Intel (RC6 residency) and AMD (gpu_busy_percent)
# Output: BUSY_PCT FREQ_MHZ

CACHE_FILE="${XDG_RUNTIME_DIR:-/tmp}/quickshell-gpu-cache"

# ── Intel GPU: use RC6 residency delta across polls (no sleep) ──
for card in 0 1 2; do
    GT="/sys/class/drm/card${card}/gt/gt0"
    if [ -f "$GT/rc6_residency_ms" ]; then
        RC6="$GT/rc6_residency_ms"
        FREQ="$GT/rps_act_freq_mhz"
        rc6=$(cat "$RC6" 2>/dev/null) || rc6=0
        wall=$(awk '{printf "%d", $1*1000}' /proc/uptime)
        busy=0
        if [ -f "$CACHE_FILE" ]; then
            read -r prev_rc6 prev_wall < "$CACHE_FILE"
            drc6=$((rc6 - prev_rc6))
            dwall=$((wall - prev_wall))
            if [ "$drc6" -ge 0 ] && [ "$dwall" -gt 0 ] && [ "$drc6" -le "$dwall" ]; then
                busy=$(( 100 * (dwall - drc6) / dwall ))
            fi
        fi
        echo "$rc6 $wall" > "$CACHE_FILE"
        freq=$(cat "$FREQ" 2>/dev/null) || freq=0
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
