#!/bin/bash
# Panel-only system usage for SysUsagePanel: memory totals, GPU presence/freq,
# load/uptime/disk, per-core CPU and top processes (grouped by name).
#
# cpu/gpu/ram/swap percentages and cpu_temp are NOT produced here: the panel
# reads them from the bar's shared cpuData (one sys-stats poll, no competing
# deltas on the shared caches).
set -euo pipefail

export LC_ALL=C

# --- Memory totals (MB), one read of /proc/meminfo ---
read -r ram_total_mb ram_used_mb swap_total_mb swap_used_mb < <(awk '
  /^MemTotal:/     {mt=$2}
  /^MemAvailable:/ {ma=$2}
  /^SwapTotal:/    {st=$2}
  /^SwapFree:/     {sf=$2}
  END {printf "%d %d %d %d\n", mt/1024, (mt-ma)/1024, st/1024, (st-sf)/1024}
' /proc/meminfo)

# --- Load / uptime / root disk (MB) ---
read -r load _ < /proc/loadavg
read -r uptime _ < /proc/uptime
uptime=${uptime%.*}
read -r _ disk_total_mb disk_used_mb _ < <(df -Pm / | awk 'NR==2')

# --- GPU presence + frequency (Intel GT, else AMD hwmon) ---
gpu_available=0
gpu_freq=0
for card in 0 1 2; do
    DEV="/sys/class/drm/card${card}"
    if [ -f "$DEV/gt/gt0/rc6_residency_ms" ]; then
        gpu_available=1
        read -r gpu_freq < "$DEV/gt/gt0/rps_act_freq_mhz" 2>/dev/null || gpu_freq=0
        break
    elif [ -f "$DEV/device/gpu_busy_percent" ]; then
        gpu_available=1
        for hwmon in "$DEV"/device/hwmon/hwmon*; do
            if [ -f "$hwmon/freq1_input" ]; then
                read -r hz < "$hwmon/freq1_input" 2>/dev/null || hz=0
                gpu_freq=$((hz / 1000000))
                break
            fi
        done
        break
    fi
done

# --- Top processes by *current* CPU, grouped by name ---
# ps pcpu is a lifetime average, so use top's second frame (a real delta).
# Private HOME/XDG_CONFIG_HOME keeps a user toprc from changing the columns.
# RAM per process = private resident (statm resident - shared) so grouped
# browser/electron helpers are not overcounted by their shared pages.
# Emits the top 12 groups by CPU plus the top 12 by RAM; the panel sorts/trims.
# The /proc/stat samples bracket top's 0.5s window, giving per-core usage free.
stat1=$(grep '^cpu[0-9]' /proc/stat)
disk1=$(awk '$3 ~ /^(sd[a-z]+|nvme[0-9]+n[0-9]+|vd[a-z]+|mmcblk[0-9]+)$/ {r+=$6; w+=$10} END {print r+0, w+0}' /proc/diskstats)
read -r up1 _ < /proc/uptime
procs=$(HOME=/nonexistent XDG_CONFIG_HOME=/nonexistent \
    top -bn2 -d0.5 -w512 -o %CPU 2>/dev/null | awk '
/^top -/ { frame++; hdr = 0; next }
frame < 2 { next }
/^ *PID / { hdr = 1; next }
!hdr || NF < 12 { next }
{
    pid = $1; pcpu = $9 + 0
    name = $12
    for (i = 13; i <= NF; i++) name = name " " $i
    gsub(/[^a-zA-Z0-9._ -]/, "", name)
    if (length(name) < 2 || name == "top" || name == "sys-stats") next
    rss_mb = 0
    if ((getline line < ("/proc/" pid "/statm")) > 0) {
        split(line, p, " ")
        rss_mb = (p[2] - p[3]) * 4 / 1024
    }
    close("/proc/" pid "/statm")
    cpu[name] += pcpu; ram[name] += rss_mb; cnt[name]++
    if (!(name in best) || pcpu > best[name]) { best[name] = pcpu; gpid[name] = pid }
}
END {
    PROCINFO["sorted_in"] = "@val_num_desc"
    n = 0
    for (k in cpu) { if (n++ >= 12) break; sel[k] = 1 }
    n = 0
    for (k in ram) { if (n++ >= 12) break; sel[k] = 1 }
    for (k in sel)
        printf "%s{\"name\":\"%s\",\"cpu\":%.1f,\"ram\":%d,\"count\":%d,\"pid\":%d}", \
               (o++ ? "," : ""), k, cpu[k], ram[k], cnt[k], gpid[k]
}')
stat2=$(grep '^cpu[0-9]' /proc/stat)
disk2=$(awk '$3 ~ /^(sd[a-z]+|nvme[0-9]+n[0-9]+|vd[a-z]+|mmcblk[0-9]+)$/ {r+=$6; w+=$10} END {print r+0, w+0}' /proc/diskstats)
read -r up2 _ < /proc/uptime

# Whole-disk throughput (bytes/s) over the same window; sectors are 512 B.
read -r disk_read_bps disk_write_bps < <(awk -v a="$disk1" -v b="$disk2" -v u1="$up1" -v u2="$up2" 'BEGIN {
    split(a, x, " "); split(b, y, " "); dt = u2 - u1; if (dt <= 0) dt = 1
    r = (y[1] - x[1]) * 512 / dt; w = (y[2] - x[2]) * 512 / dt
    printf "%d %d\n", (r < 0 ? 0 : r), (w < 0 ? 0 : w)
}')

# Spinning fans only (rpm > 0): "chip fanN" -> rpm.
fans=""
for f in /sys/class/hwmon/hwmon*/fan*_input; do
    [ -r "$f" ] || continue
    read -r rpm < "$f" 2>/dev/null || continue
    [ "${rpm:-0}" -gt 0 ] || continue
    read -r chip < "${f%/*}/name" 2>/dev/null || chip="hwmon"
    n=${f##*/}; n=${n%_input}
    fans+="${fans:+,}{\"name\":\"$chip $n\",\"rpm\":$rpm}"
done

cores=$(awk '
FNR == NR {
    t = 0; for (i = 2; i <= 9; i++) t += $i
    pt[$1] = t; pi[$1] = $5 + $6
    next
}
{
    t = 0; for (i = 2; i <= 9; i++) t += $i
    dt = t - pt[$1]; di = ($5 + $6) - pi[$1]
    printf "%s%d", (n++ ? "," : ""), (dt > 0 ? 100 * (dt - di) / dt : 0)
}' <(echo "$stat1") <(echo "$stat2"))

printf '{"ram_total":%d,"ram_used":%d,"swap_total":%d,"swap_used":%d,"gpu_available":%d,"gpu_freq":%d,"load":%s,"uptime":%d,"disk_total":%d,"disk_used":%d,"disk_read_bps":%d,"disk_write_bps":%d,"fans":[%s],"cores":[%s],"top_processes":[%s]}\n' \
    "$ram_total_mb" "$ram_used_mb" "$swap_total_mb" "$swap_used_mb" "$gpu_available" "$gpu_freq" \
    "$load" "$uptime" "$disk_total_mb" "$disk_used_mb" "$disk_read_bps" "$disk_write_bps" "$fans" "$cores" "$procs"
