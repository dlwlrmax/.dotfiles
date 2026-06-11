#!/bin/bash
# Generate JSON array of .desktop entries for launcher
# Output: [{id, name, genericName, icon, comment, exec, categories, noDisplay, terminal}]

set -euo pipefail

CACHE_FILE="/tmp/quickshell-desktop-cache.json"

# Collect all .desktop files from XDG dirs
# User dirs first so they override system (first occurrence wins)
DIRS=()
DIRS+=("${HOME}/.local/share/applications")
DIRS+=("${HOME}/.local/share/flatpak/exports/share/applications")
DIRS+=("/var/lib/flatpak/exports/share/applications")
XDG_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
IFS=':' read -ra XDG <<< "$XDG_DIRS"
DIRS+=("${XDG[@]}")

# Use cache if no .desktop file is newer than cache
if [ -f "$CACHE_FILE" ]; then
    needs_update=false
    for base in "${DIRS[@]}"; do
        if [[ "$base" == */applications ]]; then
            dir="$base"
        else
            dir="$base/applications"
        fi
        [[ -d "$dir" ]] || continue
        if find -L "$dir" -maxdepth 1 -name '*.desktop' -newer "$CACHE_FILE" -print -quit 2>/dev/null | grep -q .; then
            needs_update=true
            break
        fi
    done
    if ! $needs_update; then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

declare -A seen
entries=()

for base in "${DIRS[@]}"; do
  # XDG_DATA_DIRS entries need /applications appended; pre-suffixed entries stay as-is
  if [[ "$base" == */applications ]]; then
    dir="$base"
  else
    dir="$base/applications"
  fi
  [[ -d "$dir" ]] || continue
  while IFS= read -r -d '' file; do
    id="$(basename "$file" .desktop)"
    [[ -n "$id" && -z "${seen[$id]:-}" ]] || continue
    seen[$id]=1

    name=""
    generic=""
    icon=""
    comment=""
    exec=""
    categories=""
    keywords=""
    noDisplay="false"
    terminal="false"

    while IFS='=' read -r key val; do
      case "$key" in
        Name)          name="$val" ;;
        GenericName)   generic="$val" ;;
        Icon)          icon="$val" ;;
        Comment)       comment="$val" ;;
        Exec)          exec="$val" ;;
        Categories)    categories="$val" ;;
        Keywords)      keywords="$val" ;;
        NoDisplay)     noDisplay="$val" ;;
        Terminal)      terminal="$val" ;;
      esac
    done < <(sed '/^\[Desktop Action/,$d' "$file" 2>/dev/null | grep -E '^(Name|GenericName|Icon|Comment|Exec|Categories|Keywords|NoDisplay|Terminal)=' || true)

    # escape for JSON (backslash first, then double-quote)
    name="${name//\\/\\\\}"
    name="${name//\"/\\\"}"
    generic="${generic//\\/\\\\}"
    generic="${generic//\"/\\\"}"
    icon="${icon//\\/\\\\}"
    icon="${icon//\"/\\\"}"
    comment="${comment//\\/\\\\}"
    comment="${comment//\"/\\\"}"
    exec="${exec//\\/\\\\}"
    exec="${exec//\"/\\\"}"
    categories="${categories//\\/\\\\}"
    categories="${categories//\"/\\\"}"
    keywords="${keywords//\\/\\\\}"
    keywords="${keywords//\"/\\\"}"

    entries+=("{\"id\":\"$id\",\"name\":\"$name\",\"genericName\":\"$generic\",\"icon\":\"$icon\",\"comment\":\"$comment\",\"exec\":\"$exec\",\"categories\":\"$categories\",\"keywords\":\"$keywords\",\"noDisplay\":$noDisplay,\"terminal\":$terminal}")
  done < <(find -L "$dir" -maxdepth 1 -name '*.desktop' -type f -print0 2>/dev/null)
done

{
echo '['
for i in "${!entries[@]}"; do
  echo "${entries[$i]}$([ $i -lt $((${#entries[@]}-1)) ] && echo ',' || echo '')"
done
echo ']'
} > "$CACHE_FILE"
cat "$CACHE_FILE"
