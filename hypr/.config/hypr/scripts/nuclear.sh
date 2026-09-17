#!/bin/bash
sleep 1
killall -e xdg-desktop-portal-hyprland
killall -e xdg-desktop-portal-wlr
killall xdg-desktop-portal
if [ -x /usr/libexec/xdg-desktop-portal-hyprland ]; then
  /usr/libexec/xdg-desktop-portal-hyprland &
else
  /usr/lib/xdg-desktop-portal-hyprland &
fi
sleep 2
/usr/lib/xdg-desktop-portal &
