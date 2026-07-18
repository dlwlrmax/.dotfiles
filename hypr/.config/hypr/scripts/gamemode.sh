#!/usr/bin/env bash
# Toggle gaming mode: disable animations, blur, and VFR for lower input lag
# Usage: gamemode.sh on | off

case "$1" in
  on)
    hyprctl keyword animations:enabled false
    hyprctl keyword decoration:blur:enabled false
    hyprctl keyword misc:no_vfr true
    notify-send -u low "Gamemode ON" "Animations disabled, VFR forced"
    ;;
  off)
    hyprctl keyword animations:enabled true
    hyprctl keyword decoration:blur:enabled true
    hyprctl keyword misc:no_vfr false
    notify-send -u low "Gamemode OFF" "Animations restored"
    ;;
  *)
    echo "Usage: gamemode.sh on | off"
    exit 1
    ;;
esac
