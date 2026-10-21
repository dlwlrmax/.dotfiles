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
    hibernate)
        systemctl hibernate
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
        echo "Usage: $0 {lock|suspend|hibernate|reboot|shutdown|logout}" >&2
        exit 1
        ;;
esac
