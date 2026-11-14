#!/bin/bash
# Windows programs (.exe) in the launcher, run through Faugus Launcher.
#   exe.sh [add] [file.exe]        write ~/.local/share/applications/exe-<id>.desktop
#                                  that runs the file with `faugus-launcher <file>`
#                                  (Faugus' default prefix and runner), with the icon
#                                  pulled out of the exe (no file: pick one with a
#                                  file dialog). The exe stays where it is: it usually
#                                  needs the files next to it.
#   exe.sh remove <entry.desktop>  drop the entry and its icon (the entry's "Remove"
#                                  action). The exe itself is left alone.
# The launcher's fingerprint check picks changes up on its next open.

set -euo pipefail

self="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/scripts/exe.sh"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
icondir="$data/icons/exe"

notify() { notify-send -a Launcher "$@" 2>/dev/null || true; }
fail() { notify -u critical -i dialog-error "Windows app" "$1"; echo "$1" >&2; exit 1; }
key() { sed -n "s/^$1=//p" "$2" | head -n1; }

remove() {
  local entry="$1" path icon name
  [[ -f "$entry" ]] || fail "no such entry: $entry"
  path="$(key X-Exe-Path "$entry")"
  [[ -n "$path" ]] || fail "$(basename "$entry") is not an exe entry"
  icon="$(key Icon "$entry")"
  name="$(key Name "$entry")"
  [[ "$icon" == "$icondir/"* ]] && rm -f -- "$icon"
  rm -f -- "$entry"
  notify -i user-trash "Windows app removed" "$name"$'\n'"$path was left in place"
}

case "${1:-}" in
  remove) remove "${2:?usage: exe.sh remove <entry.desktop>}"; exit 0 ;;
  add) shift ;;
esac

command -v faugus-launcher >/dev/null 2>&1 || fail "faugus-launcher is not installed"

src="${1:-}"
if [[ -z "$src" ]]; then
  start="$HOME/Downloads"; [[ -d "$start" ]] || start="$HOME"
  if command -v kdialog >/dev/null 2>&1; then
    src="$(kdialog --title "Add Windows app" --getopenfilename "$start" "*.exe *.EXE|Windows programs")" || exit 0
  elif command -v zenity >/dev/null 2>&1; then
    src="$(zenity --file-selection --title="Add Windows app" --filename="$start/" \
                  --file-filter="Windows programs | *.exe *.EXE")" || exit 0
  else
    fail "need kdialog or zenity to pick a file"
  fi
fi
src="${src/#\~/$HOME}"
[[ -f "$src" ]] || fail "not a file: $src"
src="$(realpath "$src")"

# DOS/PE magic: "MZ" at byte offset 0.
[[ "$(od -An -tx1 -N2 "$src" | tr -d ' \n')" == 4d5a ]] || fail "$(basename "$src") is not a Windows program"

# Faugus pastes the path into a double-quoted shell string, so a path with shell
# metacharacters can't be run safely. Refuse it rather than write a broken entry.
if [[ "$src" == *[\"\`\$\\]* || "$src" == *$'\n'* ]]; then
  fail "can't add $src: the path contains one of \" \` \$ \\ or a line break"
fi

name="$(basename "$src")"; name="${name%.[Ee][Xx][Ee]}"
id="$(tr '[:upper:]' '[:lower:]' <<< "$name" | tr -c 'a-z0-9._-' '-' | sed 's/^-*//; s/-*$//')"
[[ -n "$id" ]] || id="app"

# Same file again: rewrite its entry, whichever id it got. Same name from another
# folder (setup.exe, launcher.exe, ...): keep both under a numbered id.
existing=""
for f in "$data/applications"/exe-*.desktop; do
  if [[ -f "$f" && "$(key X-Exe-Path "$f")" == "$src" ]]; then existing="$f"; break; fi
done
if [[ -n "$existing" ]]; then
  out="$existing"
  id="$(basename "$out" .desktop)"; id="${id#exe-}"
else
  base="$id"
  for n in 2 3 4 5 6 7 8 9; do
    [[ -e "$data/applications/exe-$id.desktop" ]] || break
    id="$base-$n"
  done
  out="$data/applications/exe-$id.desktop"
  [[ -e "$out" ]] && fail "too many entries named $name"
fi
mkdir -p "$(dirname "$out")"

# Icon: pulled out of the exe's resources, as PNG. 7z reads the resource section when
# told the file is a PE image (-tPE; without it an installer opens as the archive it
# carries).
icon="application-x-ms-dos-executable"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Path of the extracted image to use. The file's own icon is its first icon group
# (named groups before numbered ones, as Windows orders them); within the group take
# the widest image, deepest colour on a tie. A group lists its images as 14-byte
# records after a 6-byte header: width at +0 (0 = 256), bit depth at +6, image id
# at +12. Without a usable group, fall back to the largest image in the file.
pick_icon() {
  local grp f i n o w bits id key best_key=-1 best_id=""
  local -a b
  grp="$(find "$tmp" -type f -path '*/GROUP_ICON/*' -printf '%f\t%p\n' 2>/dev/null \
        | awk -F'\t' '{ if ($1 ~ /^[0-9]+$/) printf "1\t%012d\t%s\n", $1, $2; else printf "0\t%s\t%s\n", $1, $2 }' \
        | sort | head -n1 | cut -f3-)"
  if [[ -n "$grp" ]]; then
    read -ra b <<< "$(od -An -tu1 -v "$grp" | tr '\n' ' ')"
    n=$(( ${b[4]:-0} + 256 * ${b[5]:-0} ))
    for (( i = 0; i < n; i++ )); do
      o=$(( 6 + 14 * i ))
      (( o + 13 < ${#b[@]} )) || break
      w=${b[o]}
      if (( w == 0 )); then w=256; fi
      bits=$(( b[o + 6] + 256 * b[o + 7] ))
      id=$(( b[o + 12] + 256 * b[o + 13] ))
      key=$(( w * 1000 + bits ))
      if (( key > best_key )); then best_key=$key; best_id=$id; fi
    done
    if [[ -n "$best_id" ]]; then
      f="$(find "$(dirname "$(dirname "$grp")")" -type f \( -path "*/ICON/$best_id" -o -path "*/ICON/$best_id.ico" \) 2>/dev/null | head -n1)"
      if [[ -n "$f" ]]; then printf '%s\n' "$f"; return 0; fi
    fi
  fi
  find "$tmp" -type f -path '*/ICON/*' -printf '%s\t%p\n' 2>/dev/null | sort -rn | head -n1 | cut -f2-
}

if command -v 7z >/dev/null 2>&1 && command -v magick >/dev/null 2>&1; then
  7z x -tPE -y -o"$tmp" "$src" '.rsrc/ICON' '.rsrc/GROUP_ICON' -r >/dev/null 2>&1 || true
  big="$(pick_icon || true)"
  if [[ -n "$big" ]] && magick "${big}[0]" +repage "$tmp/icon.png" 2>/dev/null && [[ -s "$tmp/icon.png" ]]; then
    mkdir -p "$icondir"
    cp "$tmp/icon.png" "$icondir/$id.png"
    icon="$icondir/$id.png"
  fi
fi

# Exec= quoting: the path has none of the characters that need a backslash (refused
# above), only the field-code % is doubled.
cat > "$out" <<EOF
[Desktop Entry]
X-Exe-Path=$src
Type=Application
Name=$name
Comment=$src
Exec=faugus-launcher "${src//%/%%}"
Path=$(dirname "$src")
Icon=$icon
Terminal=false
Categories=Game;
Keywords=exe;windows;wine;proton;faugus;
Actions=remove-exe;

[Desktop Action remove-exe]
Name=Remove from launcher
Icon=user-trash
Exec=bash "$self" remove "$out"
EOF

notify -i "$icon" "Windows app added" "$name → $src"
echo "$out"
