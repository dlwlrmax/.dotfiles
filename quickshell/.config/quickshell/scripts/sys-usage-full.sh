#!/bin/bash
# Rich system usage for SysUsagePanel: base stats + memory totals + top processes.
#
# The base stats (cpu/gpu/gpu_freq/ram/swap/cpu_temp) come from the SAME source
# the Bar uses, so Bar (2s) and panel (2s) never run competing CPU impls:
#   - rust ~/.cargo/bin/sys-stats binary when present (shared cache), else
#   - sys-stats.sh (single unified shell impl + quickshell-sysstats-* caches).
#
# Panel-only fields (ram_total/ram_used/swap_total/swap_used/gpu_available and
# top_processes) are appended here. Output JSON keys are unchanged for QML.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$HOME/.cargo/bin/sys-stats"

# --- Base stats: prefer the rust binary, fall back to the shell impl ---
base=""
if [ -x "$BIN" ]; then
    base=$("$BIN" 2>/dev/null) || base=""
fi
if [ -z "$base" ]; then
    base=$(bash "$SCRIPT_DIR/sys-stats.sh")
fi
# Drop the closing brace so panel-only fields can be appended.
base="${base%\}}"

# --- Memory totals (MB) ---
read -r ram_total ram_used ram_avail swap_total swap_used <<< "$(free -k | awk '
  /^Mem:/  {ram_total=$2; ram_used=$3; ram_avail=$7}
  /^Swap:/ {swap_total=$2; swap_used=$3}
  END {print ram_total, ram_used, ram_avail, swap_total, swap_used}
')"
ram_total_mb=$((ram_total / 1024))
ram_used_mb=$((ram_used / 1024))
if [ "$swap_total" -gt 0 ]; then
    swap_total_mb=$((swap_total / 1024))
    swap_used_mb=$((swap_used / 1024))
else
    swap_total_mb=0
    swap_used_mb=0
fi

# --- GPU availability (same sysfs detection as the shell base impl) ---
gpu_available=0
for card in 0 1 2; do
    if [ -f "/sys/class/drm/card${card}/gt/gt0/rc6_residency_ms" ] \
        || [ -f "/sys/class/drm/card${card}/device/gpu_busy_percent" ]; then
        gpu_available=1
        break
    fi
done

# --- Base + panel totals ---
printf '%s,"ram_total":%d,"ram_used":%d,"swap_total":%d,"swap_used":%d,"gpu_available":%d,"top_processes":[' \
    "$base" "$ram_total_mb" "$ram_used_mb" "$swap_total_mb" "$swap_used_mb" "$gpu_available"

# --- Top 10 CPU processes ---
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
           (n++ ? "," : ""), name, pcpu, rss_mb
    if (n >= 10) exit
}'
echo ']}'
