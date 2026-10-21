#!/bin/bash
# Generate JSON array of .desktop entries for launcher
# Output: [{id, name, genericName, icon, comment, exec, categories, noDisplay, terminal}]
# --fingerprint: print only the desktop-file fingerprint hash and exit.

set -euo pipefail

# Locale prefix used to match localized keys (Name[en]= etc.)
LOCALE_TAG="${LANG:-}"
LOCALE_TAG="${LOCALE_TAG%%.*}"   # e.g. vi_VN.UTF-8 -> vi_VN

# Escape a string for embedding in a JSON string value
json_escape() {
  local s="${1-}"
  # Strip control chars that break JSON, keeping \n \r \t \b \f (escaped below).
  s="${s//[$'\001'-$'\007'$'\013'$'\016'-$'\037']/}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\b'/\\b}"
  s="${s//$'\f'/\\f}"
  printf '%s' "$s"
}

# True when a ';'-separated list shares an entry with the current desktop(s)
desktop_in_list() {
  local list=";$1;" d
  IFS=':' read -ra cur <<< "${XDG_CURRENT_DESKTOP:-}"
  for d in "${cur[@]}"; do
    [[ -n "$d" && "$list" == *";$d;"* ]] && return 0
  done
  return 1
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
  done | sort | sha256sum | cut -d' ' -f1 | sed 's/$/-v2/'
}

# Fingerprint mode: used by the launcher to cheaply detect changes.
if [ "${1:-}" = "--fingerprint" ]; then
  compute_fingerprint
  exit 0
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
    hidden="false"
    onlyShowIn=""
    notShowIn=""
    tryExec=""
    actionIds=""
    section="main"
    declare -A actName=() actExec=()

    [[ -r "$file" ]] || continue
    while IFS= read -r line || [[ -n "$line" ]]; do
      # Section headers: the main [Desktop Entry] group, then [Desktop Action X] groups
      # (we keep their Name/Exec for the launcher's action menu); anything else is skipped.
      if [[ "$line" == "["* ]]; then
        if [[ "$line" == "[Desktop Entry]"* ]]; then section="main"
        elif [[ "$line" == "[Desktop Action "*"]"* ]]; then
          section="${line#\[Desktop Action }"; section="${section%%]*}"
        else section="skip"; fi
        continue
      fi
      [[ "$section" == "skip" ]] && continue
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
      if [[ "$section" != "main" ]]; then
        case "$base" in
          Name) actName[$section]="$val" ;;
          Exec) actExec[$section]="$val" ;;
        esac
        continue
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
        Hidden)        hidden="$val" ;;
        OnlyShowIn)    onlyShowIn="$val" ;;
        NotShowIn)     notShowIn="$val" ;;
        TryExec)       tryExec="$val" ;;
        Actions)       actionIds="$val" ;;
      esac
    done < "$file"

    # normalize booleans to JSON true/false (empty or unset -> false)
    case "${noDisplay,,}" in true) noDisplay=true ;; *) noDisplay=false ;; esac
    # Not meant for this session: Hidden, other desktops' OnlyShowIn, our NotShowIn,
    # or a TryExec that isn't installed.
    [[ "${hidden,,}" == true ]] && noDisplay=true
    if [[ -n "$onlyShowIn" ]] && ! desktop_in_list "$onlyShowIn"; then noDisplay=true; fi
    if [[ -n "$notShowIn" ]] && desktop_in_list "$notShowIn"; then noDisplay=true; fi
    if [[ -n "$tryExec" ]]; then
      if [[ "$tryExec" == /* ]]; then [[ -x "$tryExec" ]] || noDisplay=true
      else command -v "$tryExec" >/dev/null 2>&1 || noDisplay=true; fi
    fi

    # desktop actions -> JSON array
    actions=""
    IFS=';' read -ra aids <<< "$actionIds"
    for aid in "${aids[@]}"; do
      [[ -n "$aid" && -n "${actExec[$aid]:-}" ]] || continue
      actions+="${actions:+,}{\"id\":\"$(json_escape "$aid")\",\"name\":\"$(json_escape "${actName[$aid]:-$aid}")\",\"exec\":\"$(json_escape "${actExec[$aid]}")\"}"
    done
    case "${terminal,,}" in  true) terminal=true ;; *) terminal=false ;; esac

    # escape for JSON
    name="$(json_escape "$name")"
    generic="$(json_escape "$generic")"
    icon="$(json_escape "$icon")"
    comment="$(json_escape "$comment")"
    exec="$(json_escape "$exec")"
    categories="$(json_escape "$categories")"
    keywords="$(json_escape "$keywords")"

    entries+=("{\"id\":\"$(json_escape "$id")\",\"name\":\"$name\",\"genericName\":\"$generic\",\"icon\":\"$icon\",\"comment\":\"$comment\",\"exec\":\"$exec\",\"categories\":\"$categories\",\"keywords\":\"$keywords\",\"noDisplay\":$noDisplay,\"terminal\":$terminal,\"actions\":[$actions]}")
  done < <(find -L "$dir" -maxdepth 1 -name '*.desktop' -type f -print0 2>/dev/null)
done

echo '['
for i in "${!entries[@]}"; do
  echo "${entries[$i]}$([ $i -lt $((${#entries[@]}-1)) ] && echo ',' || echo '')"
done
echo ']'
