#!/bin/bash
# AppImages in the launcher.
#   appimage.sh [add] [file.AppImage]   move it into ~/Applications, pull its .desktop
#                                       file and icon out of the image, and write
#                                       ~/.local/share/applications/appimage-<id>.desktop
#                                       (no file: pick one with a file dialog).
#                                       Re-adding the same app trashes the old version.
#   appimage.sh remove <entry.desktop>  confirm, then trash the AppImage and drop its
#                                       entry and icon (the entry's "Remove" action).
# The launcher's fingerprint check picks changes up on its next open.

set -euo pipefail

self="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/scripts/appimage.sh"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
icondir="$data/icons/appimage"

notify() { notify-send -a Launcher "$@" 2>/dev/null || true; }
fail() { notify -u critical -i dialog-error "AppImage" "$1"; echo "$1" >&2; exit 1; }
# Trash rather than delete, so a wrong click can be undone.
trash() { gio trash -- "$1" 2>/dev/null || rm -f -- "$1"; }
confirm() {
  if command -v kdialog >/dev/null 2>&1; then
    kdialog --title "$1" --warningcontinuecancel "$2" --continue-label "$1" >/dev/null 2>&1
  elif command -v zenity >/dev/null 2>&1; then
    zenity --question --title="$1" --text="$2" --ok-label="$1" >/dev/null 2>&1
  else
    return 1
  fi
}
key() { sed -n "s/^$1=//p" "$2" | head -n1; }

remove() {
  local entry="$1" path icon name
  [[ -f "$entry" ]] || fail "no such entry: $entry"
  path="$(key X-AppImage-Path "$entry")"
  [[ -n "$path" ]] || fail "$(basename "$entry") is not an AppImage entry"
  icon="$(key Icon "$entry")"
  name="$(key Name "$entry")"
  confirm "Remove" "Remove $name?"$'\n\n'"$path will be moved to the trash." || exit 0
  [[ -e "$path" ]] && trash "$path"
  [[ "$icon" == "$icondir/"* ]] && rm -f -- "$icon"
  rm -f -- "$entry"
  notify -i user-trash "AppImage removed" "$name"
}

case "${1:-}" in
  remove) remove "${2:?usage: appimage.sh remove <entry.desktop>}"; exit 0 ;;
  add) shift ;;
esac

src="${1:-}"
if [[ -z "$src" ]]; then
  start="$HOME/Downloads"; [[ -d "$start" ]] || start="$HOME"
  if command -v kdialog >/dev/null 2>&1; then
    src="$(kdialog --title "Add AppImage" --getopenfilename "$start" "*.AppImage *.appimage|AppImage files")" || exit 0
  elif command -v zenity >/dev/null 2>&1; then
    src="$(zenity --file-selection --title="Add AppImage" --filename="$start/" \
                  --file-filter="AppImage | *.AppImage *.appimage")" || exit 0
  else
    fail "need kdialog or zenity to pick a file"
  fi
fi
src="${src/#\~/$HOME}"
[[ -f "$src" ]] || fail "not a file: $src"
src="$(realpath "$src")"

# AppImage magic: "AI" + type (1 or 2) at byte offset 8.
magic="$(od -An -tx1 -j8 -N3 "$src" | tr -d ' \n')"
[[ "$magic" == 414901 || "$magic" == 414902 ]] || fail "$(basename "$src") is not an AppImage"

appdir="$HOME/Applications"
mkdir -p "$appdir"
# Characters that need escaping inside a quoted Exec= argument ( " ` $ \ and the
# field-code %) are swapped out of the file name instead.
dest="$appdir/$(basename "$src" | tr '"`$\\%' '_____')"

# On any failure after the move: put the file back and drop a half-written entry.
tmp=""
moved=""
out=""
fresh=""
cleanup() {
  local rc=$?
  [[ -n "$tmp" ]] && rm -rf "$tmp"
  (( rc == 0 )) && return
  [[ -n "$fresh" && -n "$out" ]] && rm -f -- "$out"
  if [[ -n "$moved" && -e "$dest" && ! -e "$src" ]] && mv "$dest" "$src"; then
    notify -u critical -i dialog-error "AppImage" "Adding $(basename "$src") failed; the file was moved back to $src"
  fi
}
trap cleanup EXIT

if [[ "$src" != "$dest" ]]; then
  [[ -e "$dest" ]] && fail "$dest already exists"
  mv "$src" "$dest"
  moved=1
fi
chmod +x "$dest"

tmp="$(mktemp -d)"
root="$tmp/squashfs-root"
# Type 2 runtimes extract matching paths into ./squashfs-root; type 1 can't, and
# then we fall back to a bare entry.
extract() { (cd "$tmp" && "$dest" --appimage-extract "$1" >/dev/null 2>&1) || true; }

extract '*.desktop'
embedded="$(find "$root" -maxdepth 1 -name '*.desktop' -type f 2>/dev/null | head -n1 || true)"

if [[ -n "$embedded" ]]; then
  name="$(key Name "$embedded")"
else
  name="$(basename "$dest")"; name="${name%.[Aa]pp[Ii]mage}"
fi

# id: embedded desktop file name, else the file name minus version/arch noise.
if [[ -n "$embedded" ]]; then
  id="$(basename "$embedded" .desktop)"
else
  id="$(basename "$dest")"
  id="${id%.[Aa]pp[Ii]mage}"
  id="$(sed -E 's/[-_.]?(x86[-_]64|amd64|aarch64|arm64|i686)$//; s/[-_.]?v?[0-9]+(\.[0-9]+)+.*$//' <<< "$id")"
fi
id="$(tr '[:upper:]' '[:lower:]' <<< "$id" | tr -c 'a-z0-9._-' '-' | sed 's/-*$//')"
[[ -n "$id" ]] || id="app"

# An existing entry with this id is the previous version when both images carry
# a desktop file with the same Name; otherwise ask, and keep both on "no".
replace=""
base="$id"
for n in 2 3 4 5 6 7 8 9; do
  out="$data/applications/appimage-$id.desktop"
  [[ -f "$out" ]] || break
  old="$(key X-AppImage-Path "$out")"
  if [[ "$old" == "$dest" ]] \
     || { [[ -n "$embedded" && "$(key Name "$out")" == "$name" ]]; } \
     || confirm "Replace" "Replace $(key Name "$out") ($(basename "$old")) with $(basename "$dest")?"$'\n\n'"No keeps both."; then
    replace="$old"
    break
  fi
  id="$base-$n"
done
out="$data/applications/appimage-$id.desktop"
[[ -f "$out" ]] || fresh=1
mkdir -p "$(dirname "$out")"

# .DirIcon is usually a symlink (sometimes a chain) into the image; follow it.
icon_src=""
extract .DirIcon
rel=".DirIcon"
for _ in 1 2 3 4; do
  [[ -L "$root/$rel" ]] || break
  target="$(readlink "$root/$rel")"
  [[ "$target" == /* ]] && target="${target#/}" || target="$(dirname "$rel")/$target"
  rel="$(realpath -m --relative-to="$root" "$root/$target")"
  extract "$rel"
done
[[ -f "$root/$rel" && ! -L "$root/$rel" ]] && icon_src="$root/$rel"
if [[ -z "$icon_src" && -n "$embedded" ]]; then
  iname="$(key Icon "$embedded")"
  for ext in png svg; do
    [[ -n "$iname" ]] || break
    extract "$iname.$ext"
    [[ -f "$root/$iname.$ext" ]] && { icon_src="$root/$iname.$ext"; break; }
  done
fi

icon="application-x-executable"
if [[ -n "$icon_src" ]]; then
  mkdir -p "$icondir"
  ext=png
  [[ "$(file -b --mime-type "$icon_src")" == image/svg* ]] && ext=svg
  rm -f "$icondir/$id".{png,svg}
  cp "$icon_src" "$icondir/$id.$ext"
  icon="$icondir/$id.$ext"
fi

# The launcher lists this under → actions.
remove_action="[Desktop Action remove-appimage]
Name=Remove AppImage
Icon=user-trash
Exec=bash \"$self\" remove \"$out\""

if [[ -n "$embedded" ]]; then
  # Point every Exec= at the AppImage (keeping its arguments and any `env VAR=x`
  # prefix), use our icon, add the remove action, and drop keys that only make
  # sense for an installed package or would hide the entry from the launcher.
  actions="$(awk '/^\[/ { main = ($0 == "[Desktop Entry]") } main && /^Actions=/ { print substr($0, 9); exit }' "$embedded")"
  [[ -z "$actions" || "$actions" == *";" ]] || actions+=";"
  awk -v exe="\"$dest\"" -v icon="$icon" -v actions="${actions}remove-appimage;" '
    /^\[/ {
      main = ($0 == "[Desktop Entry]"); print
      if (main) { print "X-AppImage-Path=" substr(exe, 2, length(exe) - 2); print "Actions=" actions }
      next
    }
    /^(TryExec|DBusActivatable|X-AppImage-[A-Za-z]*)=/ { next }
    main && /^(Actions|NoDisplay|Hidden|OnlyShowIn|NotShowIn)=/ { next }
    main && /^Icon=/ { print "Icon=" icon; next }
    /^Exec=/ {
      cmd = substr($0, 6); pre = ""
      if (cmd ~ /^env /) {
        pre = "env "; cmd = substr(cmd, 5)
        while (match(cmd, /^[A-Za-z_][A-Za-z0-9_]*=[^ ]* +/)) { pre = pre substr(cmd, 1, RLENGTH); cmd = substr(cmd, RLENGTH + 1) }
      }
      if (substr(cmd, 1, 1) == "\"") { i = index(substr(cmd, 2), "\""); rest = (i ? substr(cmd, i + 2) : "") }
      else { i = index(cmd, " "); rest = (i ? substr(cmd, i) : "") }
      print "Exec=" pre exe rest; next
    }
    { print }
  ' "$embedded" > "$out"
  printf '\n%s\n' "$remove_action" >> "$out"
else
  cat > "$out" <<EOF
[Desktop Entry]
X-AppImage-Path=$dest
Type=Application
Name=$name
Exec="$dest" %U
Icon=$icon
Terminal=false
Categories=Utility;
Actions=remove-appimage;

$remove_action
EOF
fi

msg="$name → $dest"
if [[ -n "$replace" && "$replace" != "$dest" && -e "$replace" ]]; then
  trash "$replace"
  msg+=$'\n'"old version moved to the trash: $(basename "$replace")"
fi
notify -i "$icon" "AppImage added" "$msg"
echo "$out"
