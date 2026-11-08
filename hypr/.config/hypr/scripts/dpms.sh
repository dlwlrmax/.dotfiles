#!/usr/bin/env bash
# Turn every display off/on (used by hypridle).
#
# Hyprland 0.57.1 implements "DPMS off" by disabling the CRTC. Sinks that
# drop their HPD link when that happens are re-added as a brand-new output,
# and since the compositor-wide DPMS state is not restored on re-add
# (hyprwm/Hyprland#16855, still present in 0.57.1) they get modeset right
# back on ~9 s later. This is why some screens never stayed off.
#
# Outputs listed in DDC_OUTPUTS are therefore powered down with DDC/CI
# power mode (VCP 0xD6) instead: their CRTC is left alone, so there is no
# HPD event and no unwanted wakeup, while the panel still goes to standby.
# Everything else uses the normal compositor DPMS path.
#
# Usage: dpms.sh on|off|toggle
set -euo pipefail

action="${1:-on}"
case "$action" in
  on|off|toggle) ;;
  *) echo "usage: $(basename "$0") on|off|toggle" >&2; exit 1 ;;
esac

# Host-specific: sinks that re-appear (HPD) when their CRTC is disabled.
DDC_OUTPUTS=" HDMI-A-1 "

state_file="${XDG_RUNTIME_DIR:-/tmp}/hypr-dpms-bus"

# Map a Hyprland output name to its ddcutil i2c bus. The result is cached so
# it can also be used while the monitor is in standby (ddcutil detect may not
# see a sleeping sink).
ddc_bus() {
  local name="$1" bus
  bus="$(awk -F= -v n="$name" '$1 == n { print $2; exit }' "$state_file" 2>/dev/null || true)"
  if [ -z "$bus" ]; then
    bus="$(ddcutil detect --brief 2>/dev/null | awk -v name="$1" '
      /I2C bus:/       { b = $NF }
      /DRM connector:/ && $NF ~ ("-" name "$") { sub("/dev/i2c-", "", b); print b; exit }
    ')"
    [ -n "$bus" ] && printf '%s=%s\n' "$name" "$bus" >>"$state_file"
  fi
  printf '%s' "$bus"
}

monitors() {
  hyprctl monitors -j | jq -r '.[].name'
}

if [ "$action" = toggle ]; then
  if hyprctl monitors -j | grep -q '"dpmsStatus": *false'; then
    action=on
  else
    action=off
  fi
fi

if [ "$action" = off ]; then
  ddc_value=4 # DPM: Off (standby)
  dpms_action=off
else
  ddc_value=1 # DPM: On
  dpms_action=on
fi

while IFS= read -r name; do
  [ -n "$name" ] || continue

  if [[ "$DDC_OUTPUTS" == *" $name "* ]]; then
    bus="$(ddc_bus "$name" || true)"
    if [ -n "$bus" ] && ddcutil -b "$bus" --noverify setvcp d6 "$ddc_value" >/dev/null 2>&1; then
      continue
    fi
    # DDC unavailable: fall through to compositor DPMS for this output.
  fi

  hyprctl dispatch "hl.dsp.dpms({ action = \"$dpms_action\", monitor = \"$name\" })" >/dev/null
done < <(monitors)
