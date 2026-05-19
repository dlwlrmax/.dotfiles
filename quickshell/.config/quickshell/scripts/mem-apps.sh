#!/bin/bash
# Output JSON: ram (totalMB, usedMB, pct), swap (totalMB, usedMB, pct), processes [{pid, name, rssMb, swapMb, ramPct}]
# Top 15 processes by RSS

# ── RAM / Swap summary (single free call) ──
eval "$(free -m | awk '/^Mem:/  {print "ramTotal="$2,"ramUsed="$3}
                       /^Swap:/ {print "swapTotal="$2,"swapUsed="$3}')"
ramPct=$((100 * ramUsed / ramTotal))
swapPct=$((swapTotal > 0 ? 100 * swapUsed / swapTotal : 0))

# ── Top processes: pid, name, rss from ps (one call) ──
# Then only read /proc/pid/status for VmSwap
echo -n '{"ram":{"total":'"$ramTotal"',"used":'"$ramUsed"',"pct":'"$ramPct"'},'
echo -n '"swap":{"total":'"$swapTotal"',"used":'"$swapUsed"',"pct":'"$swapPct"'},'
echo -n '"processes":['

first=true
while IFS=' ' read -r pid name rssKb; do
    [ -z "$pid" ] && continue
    name=$(echo "$name" | sed 's/[^a-zA-Z0-9._-]//g')
    [ -z "$name" ] && continue

    # Single /proc read for VmSwap only (rss already from ps)
    swapKb=$(grep VmSwap /proc/"$pid"/status 2>/dev/null | awk '{print $2}')
    [ -z "$swapKb" ] && swapKb=0

    rssMb=$((rssKb / 1024))
    swapMb=$((swapKb / 1024))
    [ "$rssMb" -lt 1 ] && [ "$swapMb" -lt 1 ] && continue

    ramPctVal=$(awk "BEGIN {printf \"%.1f\", ($rssKb / 1024 / $ramTotal) * 100}")

    $first && first=false || echo -n ','
    echo -n '{"pid":'"$pid"',"name":"'"$name"'","rssMb":'"$rssMb"',"swapMb":'"$swapMb"',"ramPct":'"$ramPctVal"'}'
done < <(ps -eo pid,comm,rss --sort=-rss --no-headers 2>/dev/null | head -15)

echo ']}'
