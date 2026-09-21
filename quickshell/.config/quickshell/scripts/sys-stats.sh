#!/bin/bash
# Combined CPU + RAM + Swap + GPU + Temp stats, outputs JSON once.
# Bash fallback for ~/.cargo/bin/sys-stats (used when the Rust binary is absent).
set -euo pipefail

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
CPU_CACHE="$RUNTIME_DIR/quickshell-sysstats-cpu-cache"
GPU_CACHE="$RUNTIME_DIR/quickshell-sysstats-gpu-cache"

# --- CPU ---
read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
curr_idle=$((idle + iowait))
curr_total=$((user + nice + system + idle + iowait + irq + softirq + steal))

if [ -f "$CPU_CACHE" ]; then
    read -r prev_idle prev_total < "$CPU_CACHE"
    delta_idle=$((curr_idle - prev_idle))
    delta_total=$((curr_total - prev_total))
    if [ "$delta_total" -gt 0 ]; then
        cpu_usage=$((100 * (delta_total - delta_idle) / delta_total))
    else
        cpu_usage=0
    fi
else
    cpu_usage=0
fi
echo "$curr_idle $curr_total" > "$CPU_CACHE"

# --- GPU: Intel RC6 residency delta (no sleep) or AMD gpu_busy_percent ---
gpu=0
gpu_freq=0
gpu_found=false

for card in 0 1 2; do
    GT="/sys/class/drm/card${card}/gt/gt0"
    if [ -f "$GT/rc6_residency_ms" ]; then
        rc6=$(cat "$GT/rc6_residency_ms" 2>/dev/null) || rc6=0
        wall=$(awk '{printf "%d", $1*1000}' /proc/uptime)
        if [ -f "$GPU_CACHE" ]; then
            read -r prev_rc6 prev_wall < "$GPU_CACHE"
            drc6=$((rc6 - prev_rc6))
            dwall=$((wall - prev_wall))
            if [ "$drc6" -ge 0 ] && [ "$dwall" -gt 0 ] && [ "$drc6" -le "$dwall" ]; then
                gpu=$((100 * (dwall - drc6) / dwall))
            fi
        fi
        echo "$rc6 $wall" > "$GPU_CACHE"
        gpu_freq=$(cat "$GT/rps_act_freq_mhz" 2>/dev/null) || gpu_freq=0
        gpu_found=true
        break
    fi
done

# AMD (only if Intel GT not found)
if ! $gpu_found; then
    for card in 0 1 2; do
        DEV="/sys/class/drm/card${card}/device"
        BUSY="$DEV/gpu_busy_percent"
        if [ -f "$BUSY" ]; then
            gpu=$(cat "$BUSY" 2>/dev/null) || gpu=0
            for hwmon in "$DEV"/hwmon/hwmon*; do
                if [ -f "$hwmon/freq1_input" ]; then
                    gpu_freq=$(($(cat "$hwmon/freq1_input" 2>/dev/null || echo 0) / 1000000))
                    break
                fi
            done
            break
        fi
    done
fi

# --- RAM + Swap ---
read -r ram_total ram_used ram_avail swap_total swap_used <<< "$(free -k | awk '
  /^Mem:/  {ram_total=$2; ram_used=$3; ram_avail=$7}
  /^Swap:/ {swap_total=$2; swap_used=$3}
  END {print ram_total, ram_used, ram_avail, swap_total, swap_used}
')"

ram_usage=$((100 * ram_used / ram_total))

if [ "$swap_total" -gt 0 ]; then
    swap_usage=$((100 * swap_used / swap_total))
else
    swap_usage=0
fi

# --- CPU temperature (millidegrees -> degC) ---
cpu_temp=0
for hw in /sys/class/hwmon/hwmon*; do
    label=$(cat "$hw/temp1_label" 2>/dev/null || true)
    case "$label" in
        *[Cc]pu*|*[Pp]ackage*|*[Tt]ctl*|*[Tt]die*|*[Cc]ore*)
            cpu_temp=$(( $(cat "$hw/temp1_input" 2>/dev/null || echo 0) / 1000 ))
            break
            ;;
    esac
done
if [ "$cpu_temp" -eq 0 ] && [ -r /sys/class/thermal/thermal_zone0/temp ]; then
    cpu_temp=$(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ))
fi

# --- JSON output ---
printf '{"cpu":%d,"ram":%d,"swap":%d,"gpu":%d,"cpu_temp":%d}\n' \
    "$cpu_usage" "$ram_usage" "$swap_usage" "$gpu" "$cpu_temp"
