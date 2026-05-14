#!/bin/bash
# Network speed monitor for Quickshell
# Shows upload/download speeds in human-readable format

set -e

CACHE_FILE="/tmp/quickshell-netspeed-cache"

get_interface() {
    local skip_pattern="^(lo|docker|veth|br-|virbr|tun|tap|wg|zt|dummy|bond|team|vlan)"
    local all_ifaces
    all_ifaces=$(awk -F: '/^[[:space:]]*[a-z0-9]+:/{gsub(/^[[:space:]]*/, "", $1); print $1}' /proc/net/dev | grep -v -E "${skip_pattern}" 2>/dev/null || true)

    local wifi_ifaces
    wifi_ifaces=$(echo "${all_ifaces}" | grep -E "^(wlp|wlan|wlo|wifi)" || true)

    local wired_ifaces
    wired_ifaces=$(echo "${all_ifaces}" | grep -E "^(eth|enp|ens|eno)" || true)

    while IFS= read -r iface; do
        [[ -z "${iface}" ]] && continue
        if [[ -d "/sys/class/net/${iface}" ]] && [[ "$(cat "/sys/class/net/${iface}/operstate" 2>/dev/null)" == "up" ]]; then
            echo "${iface}"
            return 0
        fi
    done <<< "${wifi_ifaces}"

    while IFS= read -r iface; do
        [[ -z "${iface}" ]] && continue
        if [[ -d "/sys/class/net/${iface}" ]] && [[ "$(cat "/sys/class/net/${iface}/operstate" 2>/dev/null)" == "up" ]]; then
            echo "${iface}"
            return 0
        fi
    done <<< "${wired_ifaces}"

    while IFS= read -r iface; do
        [[ -z "${iface}" ]] && continue
        if [[ -d "/sys/class/net/${iface}" ]] && [[ "$(cat "/sys/class/net/${iface}/operstate" 2>/dev/null)" == "up" ]]; then
            echo "${iface}"
            return 0
        fi
    done <<< "${all_ifaces}"
}

read_stats() {
    local interface="$1"
    read -r rx tx <<< "$(awk -v iface="${interface}" -F: '
        {
            gsub(/^[[:space:]]+/, "", $1)
            if ($1 == iface) {
                print $2
            }
        }
    ' /proc/net/dev | awk '{print $1, $9}')"
    echo "${rx} ${tx}"
}

human_readable() {
    local bytes="$1"
    awk -v b="${bytes}" 'BEGIN {
        if (b >= 1099511627776) {
            val = b / 1099511627776
            printf "%.1fT", val
        } else if (b >= 1073741824) {
            val = b / 1073741824
            printf "%.1fG", val
        } else if (b >= 1048576) {
            val = b / 1048576
            printf "%.1fM", val
        } else {
            val = b / 1024
            printf "%.1fK", val
        }
    }'
}

INTERFACE=$(get_interface)

if [[ -z "${INTERFACE}" ]]; then
    echo "󰤫 No network"
    exit 0
fi

read -r rx_now tx_now <<< "$(read_stats "${INTERFACE}")"
time_now=$(date +%s%N)

if [[ -f "${CACHE_FILE}" ]]; then
    read -r rx_prev tx_prev time_prev < "${CACHE_FILE}"
else
    rx_prev=0
    tx_prev=0
    time_prev=${time_now}
fi

if [[ "${rx_now}" -lt "${rx_prev}" ]]; then rx_prev=${rx_now}; fi
if [[ "${tx_now}" -lt "${tx_prev}" ]]; then tx_prev=${tx_now}; fi

rx_diff=$((rx_now - rx_prev))
tx_diff=$((tx_now - tx_prev))
time_delta=$(( time_now - time_prev ))

read -r rx_speed tx_speed <<< "$(awk -v rd="${rx_diff}" -v td="${tx_diff}" -v t="${time_delta}" 'BEGIN {
    if (t <= 0) t = 1000000000
    secs = t / 1000000000
    printf "%d %d\n", int(rd / secs), int(td / secs)
}')"

rx_human=$(human_readable "${rx_speed}")
tx_human=$(human_readable "${tx_speed}")

echo "${rx_now} ${tx_now} ${time_now}" > "${CACHE_FILE}"

echo " ${rx_human}  ${tx_human}"
