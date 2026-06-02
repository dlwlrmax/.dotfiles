#!/bin/bash
# Network speed monitor for Quickshell
# Shows upload/download speeds in human-readable format

set -e

CACHE_FILE="/tmp/quickshell-netspeed-cache"

get_interface() {
    local skip_pattern="^(lo|docker|veth|br-|virbr|tun|tap|wg|zt|dummy|bond|team|vlan)"

    # Get all interfaces that are up, sorted by preference: wifi > wired > other
    # Single awk pass to extract interfaces and filter
    awk -F: '/^[ \t]*[a-z0-9]+:/{
        gsub(/^[ \t]*/, "", $1)
        iface = $1
        if (iface !~ /^(lo|docker|veth|br-|virbr|tun|tap|wg|zt|dummy|bond|team|vlan)/) {
            print iface
        }
    }' /proc/net/dev 2>/dev/null | while read -r iface; do
        [[ -z "$iface" ]] && continue
        state=$(cat "/sys/class/net/${iface}/operstate" 2>/dev/null)
        [[ "$state" != "up" ]] && continue
        echo "$iface"
        # Prefer wifi first, then wired, then any
        case "$iface" in
            wlp*|wlan*|wlo*|wifi*) exit 0 ;;
        esac
    done | head -1
}

read_stats() {
    local interface="$1"
    read -r rx tx <<< "$(awk -v iface="${interface}" -F: '
        {gsub(/^[ \t]+/, "", $1)} $1 == iface {print $2}
    ' /proc/net/dev | awk '{print $1, $9}')"
    echo "${rx} ${tx}"
}

human_readable() {
    local bytes="$1"
    awk -v b="${bytes}" 'BEGIN {
        if (b >= 1099511627776) { val = b / 1099511627776; printf "%.1fT", val
        } else if (b >= 1073741824) { val = b / 1073741824; printf "%.1fG", val
        } else if (b >= 1048576) { val = b / 1048576; printf "%.1fM", val
        } else { val = b / 1024; printf "%.1fK", val }
    }'
}

INTERFACE=$(get_interface)

if [[ -z "${INTERFACE}" ]]; then
    echo ""
    exit 0
fi

read -r rx_now tx_now <<< "$(read_stats "${INTERFACE}")"
time_now=$(date +%s%N)

if [[ -f "${CACHE_FILE}" ]]; then
    read -r rx_prev tx_prev time_prev < "${CACHE_FILE}"
else
    echo "${rx_now} ${tx_now} ${time_now}" > "${CACHE_FILE}"
    echo "0.0K|0.0K"
    exit 0
fi

# Handle counter reset (interface down/up)
[[ "${rx_now}" -lt "${rx_prev}" ]] && rx_prev=${rx_now}
[[ "${tx_now}" -lt "${tx_prev}" ]] && tx_prev=${tx_now}

rx_diff=$((rx_now - rx_prev))
tx_diff=$((tx_now - tx_prev))
time_delta=$(( time_now - time_prev ))

read -r rx_speed tx_speed <<< "$(awk -v rd="${rx_diff}" -v td="${tx_diff}" -v t="${time_delta}" 'BEGIN {
    if (t <= 0) t = 1000000000
    secs = t / 1000000000
    printf "%d %d\n", int(rd / secs), int(td / secs)
}')"

echo "${rx_now} ${tx_now} ${time_now}" > "${CACHE_FILE}"

echo "$(human_readable "${rx_speed}")|$(human_readable "${tx_speed}")"
