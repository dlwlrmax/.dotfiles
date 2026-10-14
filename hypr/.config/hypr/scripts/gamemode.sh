#!/usr/bin/env bash
# Manual gaming profile override. The profile normally switches on/off by
# itself when a fullscreen game is focused (lua/gaming.lua); use this to force
# it on (e.g. a windowed game) or hand control back to auto.
# Usage: gamemode.sh on | off
#
# NOTE: Hyprland 0.56 rejects `hyprctl keyword`; runtime changes go through eval.

set -euo pipefail

case "${1:-}" in
  on)
    hyprctl eval 'require("lua/gaming").force(true)' >/dev/null
    notify-send -u low "Gamemode ON" "Forced: animations, blur, shadows off" || true
    ;;
  off)
    hyprctl eval 'require("lua/gaming").force(nil)' >/dev/null
    notify-send -u low "Gamemode AUTO" "Follows fullscreen games again" || true
    ;;
  *)
    echo "Usage: gamemode.sh on | off"
    exit 1
    ;;
esac
