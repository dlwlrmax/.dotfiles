#!/usr/bin/env bash
# http(s) handler (link-open.desktop). A link opened while a terminal is focused
# pops the quickshell browser picker (browserpick/) when more than one browser
# instance is running; a single instance gets the link directly; everything else
# goes to the fallback browser, like a plain mimeapps default would.
#
#   link-open.sh <url>
#   LINK_OPEN_FALLBACK=firefox.desktop link-open.sh <url>
set -u

url="${1:-}"
fallback="${LINK_OPEN_FALLBACK:-zen.desktop}"

open_fallback() { exec gtk-launch "$fallback" ${url:+"$url"}; }

# A live quickshell instance, found without forking.
qs_running() {
    local p
    for p in "${XDG_RUNTIME_DIR:-/run/user/$UID}"/quickshell/by-pid/*; do
        kill -0 "${p##*/}" 2>/dev/null && return 0
    done
    return 1
}

[ -n "$url" ] || open_fallback
command -v hyprctl >/dev/null && command -v jq >/dev/null || open_fallback

terminals='^(com\.mitchellh\.ghostty|ghostty|kitty|Alacritty|alacritty|org\.wezfurlong\.wezterm|foot|footclient|org\.kde\.konsole)$'
browsers='^(zen|firefox|librewolf|floorp|waterfox|google-chrome|google-chrome-beta|chromium|brave-browser|vivaldi-stable|microsoft-edge|opera|thorium-browser|helium)$'

# One hyprctl round trip and one jq for both questions (every fork here is time
# before the picker shows). Three lines out: focused class, browser pids, then
# one entry per browser process (separate profiles / user-data-dirs are separate
# processes), most recently focused first.
{ IFS= read -r active && IFS= read -r pids && IFS= read -r instances; } < <(
    hyprctl -j --batch 'activewindow ; clients' 2>/dev/null | jq -r -s --arg re "$browsers" '
    (.[0].class // ""),
    ([ .[1][] | select(.class | test($re)) ]
     | group_by(.pid)
     | map(sort_by(.focusHistoryID)
         # a PiP window must not be the one that gets focused or labels the instance
         | (map(select(.title != "Picture-in-Picture")) | if length > 0 then . else null end) as $main
         | ($main // .) as $w
         | { pid: .[0].pid, class: .[0].class, address: $w[0].address,
             focus: .[0].focusHistoryID, titles: ($w | map(.title)) })
     | sort_by(.focus)
     | (map(.pid) | join(" ")), tojson)') || open_fallback
[[ "$active" =~ $terminals ]] || open_fallback

# Each instance's executable and command line, handed to jq as $ARGS.named
# (e<pid>, c<pid>); a process that is gone by now is left out.
procargs=()
count=0
for pid in $pids; do
    [ -r "/proc/$pid/cmdline" ] && exe=$(readlink "/proc/$pid/exe") || continue
    procargs+=(--arg "e$pid" "$exe" --rawfile "c$pid" "/proc/$pid/cmdline")
    count=$((count + 1))
done
[ "$count" -gt 0 ] || open_fallback

# Launch argv per instance: its own executable plus the flags that pick the
# profile, so the link lands in that instance instead of the default profile.
# Written to a file, moved into place once complete.
file="${XDG_RUNTIME_DIR:-/run/user/$UID}/quickshell-link.json"
tmp="$file.$$.tmp"
id="$$-$EPOCHREALTIME"
jq -n --arg url "$url" --arg id "$id" --argjson instances "$instances" "${procargs[@]}" '
    $ARGS.named as $n
    | { url: $url, id: $id, browsers: [ $instances[]
        | . as $inst
        | ($n["e\(.pid)"] // empty) as $exe
        # Chrome rewrites its title to one space-joined string; NUL-split otherwise
        | ($n["c\(.pid)"] | split("\u0000") | map(select(. != ""))
           | if length == 1 then .[0] | split(" ") | map(select(. != "")) else . end) as $a
        | ($inst.class | test("^(zen|firefox|librewolf|floorp|waterfox)$")) as $gecko
        | [ range(1; $a | length) as $i
            | if $gecko then
                  (if ($a[$i] | test("^-{1,2}(P|profile)$")) and $i + 1 < ($a | length)
                   then $a[$i], $a[$i + 1] else empty end)
              else
                  ($a[$i] | select(test("^--(user-data-dir|profile-directory)=")))
              end ] as $keep
        | ($keep | map(capture("^--user-data-dir=(?<d>.*)").d) | first // "") as $dir
        | ($keep | index("-P") // index("--P")) as $p
        | $inst + {
            argv: ([$exe] + $keep + [$url]),
            profile: (if $dir != "" then
                          (if ($dir | test("playwright")) then "Playwright" else ($dir | split("/") | last) end)
                      elif $p != null then $keep[$p + 1]
                      else "" end) } ] }' > "$tmp" || { rm -f "$tmp"; open_fallback; }

if [ "$count" -eq 1 ]; then
    mapfile -t argv < <(jq -r '.browsers[0].argv[]' "$tmp")
    rm -f "$tmp"
    [ "${#argv[@]}" -gt 0 ] || open_fallback
    setsid -f "${argv[@]}" >/dev/null 2>&1
    exit 0
fi

# quickshell watches that file (shell.qml) and opens the picker when it changes.
# No `qs ipc call` here: starting the qs binary costs 60-140ms when it is cold.
# It answers by writing this link's id to <file>.ack; without that answer (old
# config loaded, watcher broken, stale pid) the link still goes somewhere.
qs_running || { rm -f "$tmp"; open_fallback; }
mv "$tmp" "$file" || open_fallback
for _ in {1..40}; do
    got=""
    { IFS= read -r got < "$file.ack"; } 2>/dev/null
    [ "$got" = "$id" ] && exit 0
    sleep 0.05
done
open_fallback
