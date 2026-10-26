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

[ -n "$url" ] || open_fallback
command -v hyprctl >/dev/null && command -v jq >/dev/null || open_fallback

terminals='^(com\.mitchellh\.ghostty|ghostty|kitty|Alacritty|alacritty|org\.wezfurlong\.wezterm|foot|footclient|org\.kde\.konsole)$'
active=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // ""')
[[ "$active" =~ $terminals ]] || open_fallback

# One entry per browser process (separate profiles / user-data-dirs are separate
# processes), most recently focused first.
browsers='^(zen|firefox|librewolf|floorp|waterfox|google-chrome|google-chrome-beta|chromium|brave-browser|vivaldi-stable|microsoft-edge|opera|thorium-browser|helium)$'
instances=$(hyprctl clients -j 2>/dev/null | jq -c --arg re "$browsers" '
    [ .[] | select(.class | test($re)) ]
    | group_by(.pid)
    | map(sort_by(.focusHistoryID)
        # a PiP window must not be the one that gets focused or labels the instance
        | (map(select(.title != "Picture-in-Picture")) | if length > 0 then . else null end) as $main
        | ($main // .) as $w
        | { pid: .[0].pid, class: .[0].class, address: $w[0].address,
            focus: .[0].focusHistoryID, titles: ($w | map(.title)) })
    | sort_by(.focus)') || open_fallback

# Launch argv per instance: its own executable plus the flags that pick the
# profile, so the link lands in that instance instead of the default profile.
with_argv='[]'
while IFS= read -r inst; do
    pid=$(jq -r '.pid' <<< "$inst")
    exe=$(readlink "/proc/$pid/exe") || continue
    inst=$(jq -c --argjson inst "$inst" --arg url "$url" --arg exe "$exe" -R -s '
        # Chrome rewrites its title to one space-joined string; NUL-split otherwise
        split("\u0000") | map(select(. != ""))
        | (if length == 1 then .[0] | split(" ") | map(select(. != "")) else . end) as $a
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
                      else "" end) }' "/proc/$pid/cmdline") || continue
    with_argv=$(jq -c --argjson i "$inst" '. + [$i]' <<< "$with_argv")
done < <(jq -c '.[]' <<< "$instances")

count=$(jq 'length' <<< "$with_argv")
[ "$count" -gt 0 ] || open_fallback
if [ "$count" -eq 1 ]; then
    mapfile -t argv < <(jq -r '.[0].argv[]' <<< "$with_argv")
    setsid -f "${argv[@]}" >/dev/null 2>&1
    exit 0
fi

# Handed over in a file: `qs ipc call` splits its arguments on commas.
file="${XDG_RUNTIME_DIR:-/run/user/$UID}/quickshell-link.json"
jq -n --arg url "$url" --argjson b "$with_argv" '{url: $url, browsers: $b}' > "$file.tmp" \
    && mv "$file.tmp" "$file" || open_fallback
[ "$(qs ipc call link pick 2>/dev/null)" = "ok" ] || open_fallback
