#!/bin/bash
# Generate JSON array of .desktop entries for launcher
# Output: [{id, name, genericName, icon, comment, exec, categories, noDisplay, terminal}]

set -euo pipefail

CACHE_FILE="/tmp/quickshell-desktop-cache.json"
CACHE_HASH_FILE="/tmp/quickshell-desktop-cache.sha256"

# Locale prefix used to match localized keys (Name[en]= etc.)
LOCALE_TAG="${LANG:-}"
LOCALE_TAG="${LOCALE_TAG%%.*}"   # e.g. vi_VN.UTF-8 -> vi_VN

# Escape a string for embedding in a JSON string value
json_escape() {
  local s="${1-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\b'/\\b}"
  s="${s//$'\f'/\\f}"
  printf '%s' "$s"
}

# Collect all .desktop files from XDG dirs
# User dirs first so they override system (first occurrence wins)
DIRS=()
DIRS+=("${HOME}/.local/share/applications")
DIRS+=("${HOME}/.local/share/flatpak/exports/share/applications")
DIRS+=("/var/lib/flatpak/exports/share/applications")
XDG_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
IFS=':' read -ra XDG <<< "$XDG_DIRS"
DIRS+=("${XDG[@]}")

# Build list of all .desktop dirs (canonicalize)
DESKTOP_DIRS=()
for base in "${DIRS[@]}"; do
  if [[ "$base" == */applications ]]; then
    d="$base"
  else
    d="$base/applications"
  fi
  [[ -d "$d" ]] && DESKTOP_DIRS+=("$d")
done

# Compute hash of all found .desktop files (path + mtime)
# Catches: additions, removals, and content changes
compute_fingerprint() {
  local dir
  for dir in "${DESKTOP_DIRS[@]}"; do
    find -L "$dir" -maxdepth 1 -name '*.desktop' -type f -printf '%T@ %p\n' 2>/dev/null
  done | sort | sha256sum | cut -d' ' -f1
}

# Use cache only if fingerprint matches (detects any change)
if [ -f "$CACHE_FILE" ] && [ -f "$CACHE_HASH_FILE" ]; then
    old_hash=$(cat "$CACHE_HASH_FILE")
    new_hash=$(compute_fingerprint)
    if [ "$old_hash" = "$new_hash" ]; then
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

    while IFS= read -r line; do
      [[ "$line" == *=* ]] || continue
      key="${line%%=*}"
      val="${line#*=}"
      # tolerate spaces around '=' and CRLF line endings: trim both sides
      key="${key#"${key%%[![:space:]]*}"}"; key="${key%"${key##*[![:space:]]}"}"
      val="${val#"${val%%[![:space:]]*}"}"; val="${val%"${val##*[![:space:]]}"}"
      # localized keys: Name[en_GB]= -> base Name, only accept tag matching $LANG
      base="$key"
      if [[ "$key" == *"["*"]" ]]; then
        base="${key%%[*}"
        base="${base%"${base##*[![:space:]]}"}"
        tag="${key#*[}"; tag="${tag%]}"
        [[ "$tag" == "$LOCALE_TAG" || "$tag" == "${LOCALE_TAG%%_*}" ]] || continue
      fi
      case "$base" in
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
    done < <(sed '/^\[Desktop Action/,$d' "$file" 2>/dev/null || true)

    # normalize booleans to JSON true/false (empty or unset -> false)
    case "${noDisplay,,}" in true) noDisplay=true ;; *) noDisplay=false ;; esac
    case "${terminal,,}" in  true) terminal=true ;; *) terminal=false ;; esac

    # escape for JSON
    name="$(json_escape "$name")"
    generic="$(json_escape "$generic")"
    icon="$(json_escape "$icon")"
    comment="$(json_escape "$comment")"
    exec="$(json_escape "$exec")"
    categories="$(json_escape "$categories")"
    keywords="$(json_escape "$keywords")"

    entries+=("{\"id\":\"$(json_escape "$id")\",\"name\":\"$name\",\"genericName\":\"$generic\",\"icon\":\"$icon\",\"comment\":\"$comment\",\"exec\":\"$exec\",\"categories\":\"$categories\",\"keywords\":\"$keywords\",\"noDisplay\":$noDisplay,\"terminal\":$terminal}")
  done < <(find -L "$dir" -maxdepth 1 -name '*.desktop' -type f -print0 2>/dev/null)
done

{
echo '['
for i in "${!entries[@]}"; do
  echo "${entries[$i]}$([ $i -lt $((${#entries[@]}-1)) ] && echo ',' || echo '')"
done
echo ']'
} > "$CACHE_FILE"
compute_fingerprint > "$CACHE_HASH_FILE"
cat "$CACHE_FILE"
