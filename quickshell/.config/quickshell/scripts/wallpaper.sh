#!/bin/bash
# Wallpaper helper for the shell (hyprpaper via waypaper).
#   wallpaper.sh current            path of the wallpaper on the first monitor
#   wallpaper.sh folder             wallpaper folder from waypaper's config
#   wallpaper.sh list [DIR]         "<path>\t<thumbnail>" per image (instant)
#   wallpaper.sh thumbs [DIR]       generate missing thumbnails (slow the first time)
#   wallpaper.sh set PATH           set the wallpaper on all monitors (waypaper keeps its config in sync)
#   wallpaper.sh random             set a random wallpaper
#   wallpaper.sh palette [PATH]     write the shell palette for PATH (default: current)
set -u
here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
thumbs="$cache/wallpapers"
wp_conf="${XDG_CONFIG_HOME:-$HOME/.config}/waypaper/config.ini"

folder() {
    local f=""
    [ -r "$wp_conf" ] && f=$(sed -nE 's/^folder *= *(.*)$/\1/p' "$wp_conf" | head -1)
    f="${f/#\~/$HOME}"
    echo "${f:-$HOME/Pictures/wallpapers}"
}

current() {
    hyprctl hyprpaper listactive 2>/dev/null | sed -nE 's/^[^:]+: *(.*)$/\1/p' | head -1
}

# "<path>\t<thumbnail>" per image, sorted, in ONE find+awk pass (no per-file forks).
# The thumbnail name is the sanitized path + a hash of the exact path + the mtime, so
# look-alike names never collide and an edited image gets a fresh thumbnail.
listing() {
    find -L "${1:-$(folder)}" -maxdepth 2 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -printf '%p\t%Ts\n' \
      | sort \
      | LC_ALL=C awk -F'\t' -v dir="$thumbs" '
            function hash(s,   i, h) { h = 5381; for (i = 1; i <= length(s); i++) h = (h * 33 + index(CHARS, substr(s, i, 1)) + 7 * i) % 4294967291; return sprintf("%08x", h) }
            BEGIN { for (i = 1; i < 256; i++) CHARS = CHARS sprintf("%c", i) }
            { name = $1; gsub(/[^A-Za-z0-9._-]/, "_", name); n = length(name); if (n > 80) name = substr(name, n - 79)
              printf "%s\t%s/%s-%s-%s.jpg\n", $1, dir, name, hash($1), $2 }'
}

list() {
    mkdir -p "$thumbs"
    listing "${1:-}"
}

# Slow the first time: make every missing thumbnail (6 at a time). Each is written to a
# temp name and renamed, so an interrupted run never leaves a truncated thumbnail behind.
thumbs() {
    mkdir -p "$thumbs"
    local f t all
    all=$(listing "${1:-}")
    while IFS=$'\t' read -r f t; do
        [ -n "$f" ] && [ ! -s "$t" ] && printf '%s\0%s\0' "$f" "$t"
    done <<< "$all" \
      | xargs -0 -r -n2 -P6 sh -c 't="$1"; tmp="${t%.jpg}.part.jpg"; magick "$0[0]" -auto-orient -resize 480x270^ -gravity center -extent 480x270 -quality 80 "$tmp" 2>/dev/null && mv -f "$tmp" "$t" || rm -f "$tmp"'
    # Forget thumbnails of images that are gone; never when the listing is empty
    # (e.g. the folder is temporarily unavailable).
    if [ -n "$all" ]; then
        cut -f2 <<< "$all" | sort > "$thumbs/.keep.tmp"
        find "$thumbs" -maxdepth 1 -name '*.jpg' | sort | comm -23 - "$thumbs/.keep.tmp" | xargs -r rm -f
        rm -f "$thumbs/.keep.tmp"
    fi
    return 0
}

case "${1:-}" in
    current) current ;;
    folder)  folder ;;
    list)    list "${2:-}" ;;
    thumbs)  thumbs "${2:-}" ;;
    set)
        [ -f "${2:-}" ] || { echo "no such file: ${2:-}" >&2; exit 1; }
        waypaper --wallpaper "$2" ;;
    random)  waypaper --random ;;
    palette)
        img="${2:-$(current)}"
        [ -f "$img" ] || { echo "no wallpaper" >&2; exit 1; }
        python3 "$here/palette.py" "$img" --apply >/dev/null ;;
    *) echo "usage: $0 {current|folder|list [DIR]|thumbs [DIR]|set PATH|random|palette [PATH]}" >&2; exit 1 ;;
esac
