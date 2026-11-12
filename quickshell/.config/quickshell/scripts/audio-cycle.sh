#!/bin/bash
# Cycle default audio sink, move all streams, notify.
# Invoked via: qs ipc call audio cycle (Super+Ctrl+A)
# HDMI/DP outputs are skipped unless --include-hdmi is passed, mirroring the
# "Hide HDMI output" setting in the Settings panel.
set -u
include_hdmi=0
for arg in "$@"; do
    [ "$arg" = "--include-hdmi" ] && include_hdmi=1
done
current=$(pactl get-default-sink 2>/dev/null || true)
# Physical sinks only: keep blocks with ALSA api or a hardware bus
# (pci/usb/bluetooth). Skips virtual sinks (EasyEffects, null, combined).
# Keep the HDMI test in sync with isHdmi() in volume/VolumePanel.qml.
mapfile -t sinks < <(pactl list sinks 2>/dev/null | awk -v include_hdmi="$include_hdmi" '
    function usable() {
        if (name == "" || !(api == "alsa" || bus != "")) return 0
        if (include_hdmi == 1) return 1
        return tolower(name) !~ /hdmi/ && tolower(profile) !~ /hdmi/ && tolower(alsaid) !~ /hdmi/
    }
    /^Sink #/ {
        if (usable()) print name
        name = ""; api = ""; bus = ""; profile = ""; alsaid = ""
    }
    $1 == "Name:" { name = $2 }
    $1 == "device.api" { gsub(/"/, "", $3); api = $3 }
    $1 == "device.bus" { gsub(/"/, "", $3); bus = $3 }
    $1 == "device.profile.name" { gsub(/"/, "", $3); profile = $3 }
    $1 == "alsa.id" { gsub(/"/, "", $3); alsaid = $3 }
    END { if (usable()) print name }
')
[ "${#sinks[@]}" -eq 0 ] && exit 0
next="${sinks[0]}"
for i in "${!sinks[@]}"; do
    if [ "${sinks[$i]}" = "$current" ]; then
        next="${sinks[$(( (i + 1) % ${#sinks[@]} ))]}"
        break
    fi
done
[ "$next" = "$current" ] && exit 0
pactl set-default-sink "$next"
while read -r idx _; do
    [ -n "$idx" ] && pactl move-sink-input "$idx" "$next" 2>/dev/null
done < <(pactl list short sink-inputs 2>/dev/null | awk '{print $1}')
bash "$(dirname "$0")/audio-notify.sh" "$next"
# Report new sink on stdout so the shell syncs its poll baseline (no dup notify)
echo "$next"
