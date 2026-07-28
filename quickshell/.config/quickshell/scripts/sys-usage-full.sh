#!/bin/bash
# Combined CPU + GPU + RAM + Swap stats, outputs JSON
# Uses separate CPU cache to avoid clashing with bar widget polling
set -euo pipefail

# --- CPU: delta from /proc/stat, separate cache file ---
CPU_CACHE="/tmp/quickshell-sysusage-cpu-cache"

read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
curr_idle=$((idle + iowait))
curr_total=$((user + nice + system + idle + iowait + irq + softirq + steal))

if [ -f "$CPU_CACHE" ]; then
    read -r prev_idle prev_total < "$CPU_CACHE"
    delta_idle=$((curr_idle - prev_idle))
    delta_total=$((curr_total - prev_total))
    [ "$delta_total" -gt 0 ] && cpu=$((100 * (delta_total - delta_idle) / delta_total)) || cpu=0
else
    cpu=0
fi
echo "$curr_idle $curr_total" > "$CPU_CACHE"

# --- GPU: Intel RC6 residency or AMD gpu_busy_percent ---
gpu=0
gpu_freq=0
gpu_found=false

# Intel
for card in 0 1 2; do
    GT="/sys/class/drm/card${card}/gt/gt0"
    if [ -f "$GT/rc6_residency_ms" ]; then
        r1=$(cat "$GT/rc6_residency_ms" 2>/dev/null) || r1=0
        f1=$(cat "$GT/rps_act_freq_mhz" 2>/dev/null) || f1=0
        sleep 0.5
        r2=$(cat "$GT/rc6_residency_ms" 2>/dev/null) || r2=0
        f2=$(cat "$GT/rps_act_freq_mhz" 2>/dev/null) || f2=0
        drc6=$((r2 - r1))
        if [ "$drc6" -ge 0 ] && [ "$drc6" -le 500 ]; then
            gpu=$((100 * (500 - drc6) / 500))
        fi
        gpu_freq=$(((f1 + f2) / 2))
        gpu_found=true
        break
    fi
done

# AMD (only if Intel not found)
if ! $gpu_found; then
    for card in 0 1 2; do
        DEV="/sys/class/drm/card${card}/device"
        BUSY="$DEV/gpu_busy_percent"
        if [ -f "$BUSY" ]; then
            gpu=$(cat "$BUSY" 2>/dev/null) || gpu=0
            for hwmon in "$DEV"/hwmon/hwmon*; do
                if [ -f "$hwmon/freq1_input" ]; then
                    gpu_freq=$(($(cat "$hwmon/freq1_input") / 1000000))
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

ram=$((100 * ram_used / ram_total))
ram_total_mb=$((ram_total / 1024))
ram_used_mb=$((ram_used / 1024))

if [ "$swap_total" -gt 0 ]; then
    swap=$((100 * swap_used / swap_total))
    swap_total_mb=$((swap_total / 1024))
    swap_used_mb=$((swap_used / 1024))
else
    swap=0
    swap_total_mb=0
    swap_used_mb=0
fi

# --- JSON output ---
printf '{"cpu":%d,"gpu":%d,"gpu_freq":%d,"ram":%d,"ram_total":%d,"ram_used":%d,"swap":%d,"swap_total":%d,"swap_used":%d' \
    "$cpu" "$gpu" "$gpu_freq" "$ram" "$ram_total_mb" "$ram_used_mb" "$swap" "$swap_total_mb" "$swap_used_mb"

# --- Top 10 CPU processes ---
echo -n ',"top_processes":['
ps -eo comm:50,pcpu,rss --sort=-pcpu --no-headers 2>/dev/null | awk '
{
    # last field = rss, second-to-last = pcpu, rest = name
    rss = $NF; pcpu = $(NF-1)
    $NF = ""; $(NF-1) = ""
    name = $0
    sub(/[[:space:]]+$/, "", name)
    gsub(/[^a-zA-Z0-9._ -]/, "", name)
    sub(/^[[:space:]]+/, "", name)
    sub(/[[:space:]]+$/, "", name)
    if (name ~ /^\[/) next
    if (length(name) < 2) next
    rss_mb = int(rss / 1024)
    printf "%s{\"name\":\"%s\",\"cpu\":\"%s\",\"ram\":%d}",
           (NR > 1 ? "," : ""), name, pcpu, rss_mb
    if (NR >= 10) exit
}'
echo ']}'
