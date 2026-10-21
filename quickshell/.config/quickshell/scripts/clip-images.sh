#!/bin/bash
# Decode the newest clipboard-history images to files for thumbnails/preview.
# Prints "<id>\t<path>" per image. Files live in the runtime dir (RAM, per login)
# and are pruned to the ids still in history.
set -u
dir="${XDG_RUNTIME_DIR:-/tmp}/quickshell-clip"
mkdir -p "$dir"
limit="${1:-24}"

keep=()
n=0
while IFS=$'\t' read -r id label; do
    [[ "$label" == *"binary data"* ]] || continue
    ext=$(sed -E 's/.*binary data [0-9.]+ [A-Za-z]+ ([a-z0-9]+).*/\1/' <<< "$label")
    [[ "$ext" =~ ^[a-z0-9]{2,5}$ ]] || ext=png
    out="$dir/$id.$ext"
    if [ ! -s "$out" ]; then
        cliphist decode "$id" > "$out.tmp" 2>/dev/null && mv "$out.tmp" "$out" || { rm -f "$out.tmp"; continue; }
    fi
    printf '%s\t%s\n' "$id" "$out"
    keep+=("$out")
    n=$((n + 1))
    [ "$n" -ge "$limit" ] && break
done < <(cliphist list)

# prune files that are no longer wanted
for f in "$dir"/*; do
    [ -e "$f" ] || continue
    skip=0
    for k in "${keep[@]}"; do [ "$f" = "$k" ] && { skip=1; break; }; done
    [ "$skip" -eq 0 ] && rm -f "$f"
done
