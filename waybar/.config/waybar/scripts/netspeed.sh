#!/bin/bash
# Network speed monitor for Waybar
# Shows upload/download speeds in human-readable format

set -e

# Cache file for storing previous values
CACHE_FILE="/tmp/waybar-netspeed-cache"

# Get default network interface (prioritize common physical interfaces, skip virtual/docker)
get_interface() {
    # Skip these interface prefixes (virtual, docker, loopback)
    local skip_pattern="^(lo|docker|veth|br-|virbr|tun|tap|wg|zt|dummy|bond|team|vlan)"

    # Get all interfaces from /proc/net/dev (handles leading whitespace)
    local all_ifaces
    all_ifaces=$(awk -F: '/^[[:space:]]*[a-z0-9]+:/{gsub(/^[[:space:]]*/, "", $1); print $1}' /proc/net/dev | grep -v -E "${skip_pattern}" 2>/dev/null || true)

    # Priority: wireless interfaces (wlp, wlan, wlo) first
    local wifi_ifaces
    wifi_ifaces=$(echo "${all_ifaces}" | grep -E "^(wlp|wlan|wlo|wifi)" || true)

    # Then wired interfaces (eth, enp, ens, eno)
    local wired_ifaces
    wired_ifaces=$(echo "${all_ifaces}" | grep -E "^(eth|enp|ens|eno)" || true)

    # Check wifi interfaces first
    while IFS= read -r iface; do
        [[ -z "${iface}" ]] && continue
        if [[ -d "/sys/class/net/${iface}" ]] && [[ "$(cat "/sys/class/net/${iface}/operstate" 2>/dev/null)" == "up" ]]; then
            echo "${iface}"
            return 0
        fi
    done <<< "${wifi_ifaces}"

    # Check wired interfaces
    while IFS= read -r iface; do
        [[ -z "${iface}" ]] && continue
        if [[ -d "/sys/class/net/${iface}" ]] && [[ "$(cat "/sys/class/net/${iface}/operstate" 2>/dev/null)" == "up" ]]; then
            echo "${iface}"
            return 0
        fi
    done <<< "${wired_ifaces}"

    # Last resort: any remaining non-virtual interface
    while IFS= read -r iface; do
        [[ -z "${iface}" ]] && continue
        if [[ -d "/sys/class/net/${iface}" ]] && [[ "$(cat "/sys/class/net/${iface}/operstate" 2>/dev/null)" == "up" ]]; then
            echo "${iface}"
            return 0
        fi
    done <<< "${all_ifaces}"
}

# Read network stats for interface
read_stats() {
    local interface="$1"
    local rx tx

    # Parse /proc/net/dev: remove leading spaces, split on colon, find matching interface
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

# Convert bytes to human-readable format using awk for floating point
# Fixed width: 8 chars total (number + unit) with space padding
# Always shows KiB or larger (no raw bytes)
human_readable() {
    local bytes="$1"

    # Use awk for unit conversion with fixed width and space padding
    awk -v b="${bytes}" 'BEGIN {
        if (b >= 1099511627776) {
            val = b / 1099511627776
            printf "%5.1fTiB", val
        } else if (b >= 1073741824) {
            val = b / 1073741824
            printf "%5.1fGiB", val
        } else if (b >= 1048576) {
            val = b / 1048576
            printf "%5.1fMiB", val
        } else {
            # Show KiB for everything below 1 MiB (no raw bytes)
            val = b / 1024
            printf "%5.1fKiB", val
        }
    }'
}

# Main
INTERFACE=$(get_interface)

if [[ -z "${INTERFACE}" ]]; then
    echo '{"text":"󰤫 No network", "tooltip":"No active network interface found"}'
    exit 0
fi

# Read current stats
read -r rx_now tx_now <<< "$(read_stats "${INTERFACE}")"
time_now=$(date +%s%N)

# Check for cached values
if [[ -f "${CACHE_FILE}" ]]; then
    read -r rx_prev tx_prev time_prev < "${CACHE_FILE}"
else
    rx_prev=0
    tx_prev=0
    time_prev=${time_now}
fi

# Calculate time delta (nanoseconds)
time_delta=$(( time_now - time_prev ))

# Handle counter wrap-around (rx/tx can reset on reboot)
if [[ "${rx_now}" -lt "${rx_prev}" ]]; then
    rx_prev=${rx_now}
fi
if [[ "${tx_now}" -lt "${tx_prev}" ]]; then
    tx_prev=${tx_now}
fi

# Calculate bytes difference
rx_diff=$((rx_now - rx_prev))
tx_diff=$((tx_now - tx_prev))

# Convert to bytes per second using awk for floating point
# time_delta is in nanoseconds, divide by 1e9 to get seconds
read -r rx_speed tx_speed <<< "$(awk -v rd="${rx_diff}" -v td="${tx_diff}" -v t="${time_delta}" 'BEGIN {
    # Avoid division by zero
    if (t <= 0) t = 1000000000
    secs = t / 1000000000
    # Calculate bytes per second
    printf "%d %d\n", int(rd / secs), int(td / secs)
}')"

# Format for display
rx_human=$(human_readable "${rx_speed}")
tx_human=$(human_readable "${tx_speed}")

# Store current values for next run
echo "${rx_now} ${tx_now} ${time_now}" > "${CACHE_FILE}"

# Output JSON for Waybar
TEXT="󰁣 ${rx_human} 󰁢 ${tx_human}"
TOOLTIP="Interface: ${INTERFACE}\nDownload: ${rx_human}\nUpload: ${tx_human}"

# Class for CSS styling based on activity
CLASS="netspeed"
if [[ "${rx_speed}" -gt 1048576 ]] || [[ "${tx_speed}" -gt 1048576 ]]; then
    CLASS="netspeed-high"
elif [[ "${rx_speed}" -gt 102400 ]] || [[ "${tx_speed}" -gt 102400 ]]; then
    CLASS="netspeed-med"
fi

echo "{\"text\":\"${TEXT}\", \"tooltip\":\"${TOOLTIP}\", \"class\":\"${CLASS}\"}"
