#!/usr/bin/env bash
# Toggle gaming mode: disable animations, blur, and VFR for lower input lag
# Usage: gamemode.sh on | off
#
# NOTE: Hyprland 0.56 rejects `hyprctl keyword` ("keyword can't work with
# non-legacy parsers. Use eval."), so runtime config changes go through
# hl.config(). The 0.56 option name for VFR is debug.vfr (not misc:no_vfr).

set -euo pipefail

case "${1:-}" in
  on)
    hyprctl eval 'hl.config({ animations = { enabled = false }, decoration = { blur = { enabled = false } }, debug = { vfr = false } })' >/dev/null
    notify-send -u low "Gamemode ON" "Animations disabled, VFR forced" || true
    ;;
  off)
    hyprctl eval 'hl.config({ animations = { enabled = true }, decoration = { blur = { enabled = true } }, debug = { vfr = true } })' >/dev/null
    notify-send -u low "Gamemode OFF" "Animations restored" || true
    ;;
  *)
    echo "Usage: gamemode.sh on | off"
    exit 1
    ;;
esac
