#!/usr/bin/env bash
# Hyprland 0.56 parses `hyprctl dispatch` arguments as Lua, so the classic
# `hyprctl dispatch dpms on` fails with a parse error (verified on 0.56.2).
# hypridle.conf is hyprlang and cannot carry the nested Lua quoting reliably,
# so it calls this wrapper instead.
#
# Usage: dpms.sh on|off|toggle
set -euo pipefail

action="${1:-on}"
case "$action" in
  on|off|toggle) ;;
  *) echo "usage: $(basename "$0") on|off|toggle" >&2; exit 1 ;;
esac

exec hyprctl dispatch "hl.dsp.dpms({ action = \"$action\" })"
