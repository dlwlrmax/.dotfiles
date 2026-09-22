#!/usr/bin/env bash
# Log out of Hyprland. 0.56 parses `hyprctl dispatch` arguments as Lua, so the
# classic `hyprctl dispatch exit` used by rofi-power-menu is a parse error.
set -euo pipefail

exec hyprctl dispatch 'hl.dsp.exit()'
