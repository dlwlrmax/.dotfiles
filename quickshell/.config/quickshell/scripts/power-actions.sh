#!/bin/bash
# Power actions for Quickshell power menu
set -e

case "$1" in
    lock)
        hyprlock
        ;;
    suspend)
        systemctl suspend
        ;;
    reboot)
        systemctl reboot
        ;;
    shutdown)
        systemctl poweroff
        ;;
    logout)
        hyprctl dispatch exit
        ;;
    *)
        echo "Usage: $0 {lock|suspend|reboot|shutdown|logout}" >&2
        exit 1
        ;;
esac
