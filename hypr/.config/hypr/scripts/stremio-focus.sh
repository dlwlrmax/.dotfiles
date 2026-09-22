#!/usr/bin/env bash
# Cycle focus: current -> Stremio -> mpv -> browser PiP -> previous window
# Uses an address file to avoid Hyprland's unreliable focus history.
# NOTE: hyprctl dispatch takes Lua here (Hyprland 0.56): hl.dsp.focus({ window = ... })
# Native `focuswindow class:...` syntax does NOT work in this build.
#
# Hardened: the previous-window file lives in the runtime dir instead of a
# predictable /tmp path, and its contents are validated (0x[0-9a-f]+) before
# being interpolated into a Lua string handed to hyprctl.

set -uo pipefail

STREMIO_CLASS="com.stremio.Stremio"
MPV_CLASS="mpv"
PREV_FILE="${XDG_RUNTIME_DIR:-/tmp}/stremio-prev-window"

# Fallback location only: keep the file private if we ever land in /tmp.
[ -n "${XDG_RUNTIME_DIR:-}" ] || umask 077

# Freeze PIP hover-peek so cycling focus onto a PIP never shoves it aside.
hyprctl eval 'local ok,m=pcall(require,"lua/pippeek") if ok and m and m.block_until_leave then m.block_until_leave() end return "ok"' >/dev/null 2>&1

command -v jq >/dev/null 2>&1 || exit 1

clients=$(hyprctl clients -j 2>/dev/null) || exit 1

# Resolve ring members live; "-" when the window is not running.
# PIP detection mirrors lua/pippeek.lua is_pip(): mpv/stremio classes, a pinned
# floating browser window (PIP titles follow the media title), or a title match.
read -r stremio_addr mpv_addr pip_addr < <(jq -r --arg sc "$STREMIO_CLASS" --arg mc "$MPV_CLASS" '
  def ispip:
    (.floating == true) and
    (((.class // "") == $mc)
     or ((.class // "") | test("^(stremio-enhanced|com\\.stremio\\.Stremio)$"))
     or ((((.class // "") | test("^(zen|zen-beta|firefox|chromium|Chromium|chromium-browser|google-chrome|Google-chrome)$")) and (.pinned == true)))
     or (((.title // "") | ascii_downcase) | test("picture.*picture")));
  [ (first(.[] | select((.class // "") == $sc)) | .address // "-"),
    (first(.[] | select((.class // "") == $mc)) | .address // "-"),
    (first(.[] | select(ispip)) | .address // "-") ] | @tsv
' <<<"$clients")

active=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // "-"')

: "${stremio_addr:=-}"
: "${mpv_addr:=-}"
: "${pip_addr:=-}"
: "${active:=-}"

focus_addr() {
  local addr="${1:-}"
  # Never interpolate unvalidated text into the Lua dispatcher.
  [[ "$addr" =~ ^0x[0-9a-fA-F]+$ ]] || return 1
  hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null 2>&1
}

focus_prev() {
  local prev_addr=""
  if [ -r "$PREV_FILE" ]; then
    prev_addr=$(head -c 64 "$PREV_FILE" 2>/dev/null)
    rm -f "$PREV_FILE"
  fi
  focus_addr "$prev_addr"
}

save_prev() {
  local addr="${1:-}"
  [[ "$addr" =~ ^0x[0-9a-fA-F]+$ ]] || return 0
  ( umask 077; printf '%s\n' "$addr" > "$PREV_FILE" )
}

if [ "$active" != "-" ] && [ "$active" = "$stremio_addr" ]; then
  # Stremio focused -> mpv, else PiP, else back to saved previous window
  if [ "$mpv_addr" != "-" ]; then focus_addr "$mpv_addr"
  elif [ "$pip_addr" != "-" ]; then focus_addr "$pip_addr"
  else focus_prev; fi
elif [ "$active" != "-" ] && [ "$active" = "$pip_addr" ]; then
  # PiP focused -> back to saved previous window
  focus_prev
elif [ "$active" != "-" ] && [ "$active" = "$mpv_addr" ]; then
  # mpv focused -> PiP, else back to saved previous window
  if [ "$pip_addr" != "-" ]; then focus_addr "$pip_addr"
  else focus_prev; fi
else
  # Normal window -> Stremio, else mpv, else PiP
  save_prev "$active"
  if [ "$stremio_addr" != "-" ]; then focus_addr "$stremio_addr"
  elif [ "$mpv_addr" != "-" ]; then focus_addr "$mpv_addr"
  elif [ "$pip_addr" != "-" ]; then focus_addr "$pip_addr"
  else rm -f "$PREV_FILE"; fi
fi
