#!/bin/bash
set -u
sleep 1
killall -e xdg-desktop-portal-hyprland
killall -e xdg-desktop-portal-wlr
killall xdg-desktop-portal
if [ -x /usr/libexec/xdg-desktop-portal-hyprland ]; then
  nohup /usr/libexec/xdg-desktop-portal-hyprland >/dev/null 2>&1 &
  disown
else
  nohup /usr/lib/xdg-desktop-portal-hyprland >/dev/null 2>&1 &
  disown
fi
sleep 2
nohup /usr/lib/xdg-desktop-portal >/dev/null 2>&1 &
disown
