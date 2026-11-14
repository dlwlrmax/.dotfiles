#!/bin/bash
# Tests for the launcher's helper scripts (exe.sh, remove-entry.sh, list-programs.sh).
# They run against a throwaway HOME with stand-ins for notify-send, gio and
# faugus-launcher, so nothing touches the real launcher entries and no
# notification pops up.   Usage: tests/scripts.sh   (or: tests/run.sh)

here="$(cd "$(dirname "$0")" && pwd)"
scripts="$here/../scripts"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export HOME="$work/home"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_DIRS="$work/sys"
apps="$XDG_DATA_HOME/applications"
mkdir -p "$apps" "$work/sys/applications" "$work/bin" "$HOME/trash"

printf '#!/bin/sh\nexit 0\n' > "$work/bin/notify-send"
printf '#!/bin/sh\nexit 0\n' > "$work/bin/faugus-launcher"
# gio trash -- <file>: move it aside, like the real trash.
printf '#!/bin/sh\n[ "$1" = trash ] || exit 1\nshift\n[ "$1" = -- ] && shift\nmv -- "$1" "$HOME/trash/"\n' > "$work/bin/gio"
chmod +x "$work/bin"/*
export PATH="$work/bin:$PATH"

passed=0; failed=0
ok() { passed=$((passed + 1)); echo "  ok   $1"; }
bad() { failed=$((failed + 1)); echo "  FAIL $1"; }
check() { local name="$1"; shift; if "$@"; then ok "$name"; else bad "$name"; fi; }
key() { sed -n "s/^$1=//p" "$2" | head -n1; }
pe() { mkdir -p "$(dirname "$1")"; printf 'MZ\220\000rest of a program' > "$1"; }   # just the DOS magic

echo "list-programs.sh"
g="$work/games"
mkdir -p "$g/sub" "$g/.hidden"
pe "$g/Game.EXE"; : > "$g/tool.AppImage"; : > "$g/readme.txt"; : > "$g/$(printf 'bad\nname').exe"
out="$(bash "$scripts/list-programs.sh" "$g/" | sort)"
check "header names the folder asked for" grep -qxF "ok	$g/" <<< "$out"
check "lists sub-folders" grep -qxF "d	sub" <<< "$out"
check "lists .exe and .AppImage in any case" bash -c 'grep -qxF "f	Game.EXE" <<< "$1" && grep -qxF "f	tool.AppImage" <<< "$1"' _ "$out"
check "leaves other files out" bash -c '! grep -q readme <<< "$1"' _ "$out"
check "leaves names with a line break out" bash -c '[ "$(grep -c . <<< "$1")" = 5 ]' _ "$out"
check "unreadable folder reports fail" bash -c '[ "$(bash "$1/list-programs.sh" /nonexistent/)" = "fail	/nonexistent/" ]' _ "$scripts"
check "~ is the home folder" bash -c 'bash "$1/list-programs.sh" "~/" | grep -qxF "ok	~/"' _ "$scripts"

echo "exe.sh"
pe "$g/Game.EXE"
e="$(bash "$scripts/exe.sh" add "$g/Game.EXE" 2>/dev/null)"
check "add writes exe-<id>.desktop" test "$e" = "$apps/exe-game.desktop" -a -f "$apps/exe-game.desktop"
check "entry runs the file through faugus-launcher" test "$(key Exec "$e")" = "faugus-launcher \"$g/Game.EXE\""
check "entry records the path and its remove action" bash -c 'grep -qxF "X-Exe-Path=$2" "$1" && grep -qxF "Actions=remove-exe;" "$1"' _ "$e" "$g/Game.EXE"
check "the exe stays where it is" test -f "$g/Game.EXE"
bash "$scripts/exe.sh" add "$g/Game.EXE" >/dev/null 2>&1
check "adding the same file again keeps one entry" bash -c '[ "$(ls "$1" | grep -c "^exe-")" = 1 ]' _ "$apps"

pe "$g/other/game.exe"
e2="$(bash "$scripts/exe.sh" add "$g/other/game.exe" 2>/dev/null)"
check "same name from another folder gets a numbered id" test "$e2" = "$apps/exe-game-2.desktop"
bash "$scripts/exe.sh" remove "$e" >/dev/null 2>&1
check "remove drops the entry, not the exe" test ! -e "$e" -a -f "$g/Game.EXE"
e3="$(bash "$scripts/exe.sh" add "$g/other/game.exe" 2>/dev/null)"
check "re-adding finds its numbered entry (no duplicate)" bash -c '[ "$1" = "$2" ] && [ "$(ls "$3" | grep -c "^exe-")" = 1 ]' _ "$e3" "$e2" "$apps"

pe "$g/100% done.exe"
e4="$(bash "$scripts/exe.sh" add "$g/100% done.exe" 2>/dev/null)"
check "a % in the path is doubled in Exec" test "$(key Exec "$e4")" = "faugus-launcher \"$g/100%% done.exe\""
check "a file that isn't a program is refused" bash -c '! bash "$1/exe.sh" add "$2" >/dev/null 2>&1' _ "$scripts" "$g/readme.txt"
pe "$g/pay\$up.exe"
check "a path with shell metacharacters is refused" bash -c '! bash "$1/exe.sh" add "$2" >/dev/null 2>&1' _ "$scripts" "$g/pay\$up.exe"

echo "remove-entry.sh"
printf '[Desktop Entry]\nType=Application\nName=Mine\nExec=mine\n' > "$apps/mine.desktop"
bash "$scripts/remove-entry.sh" mine >/dev/null 2>&1
check "an entry of the user's goes to the trash" test ! -e "$apps/mine.desktop" -a -f "$HOME/trash/mine.desktop"
check "an unknown id is refused" bash -c '! bash "$1/remove-entry.sh" nope >/dev/null 2>&1' _ "$scripts"
check "an id with a slash is refused" bash -c '! bash "$1/remove-entry.sh" ../x >/dev/null 2>&1' _ "$scripts"
printf '[Desktop Entry]\nName=Real\nExec=real\n' > "$work/real.desktop"
ln -s "$work/real.desktop" "$apps/linked.desktop"
check "a symlinked entry is refused" bash -c '! bash "$1/remove-entry.sh" linked >/dev/null 2>&1 && [ -L "$2/linked.desktop" ]' _ "$scripts" "$apps"

printf '[Desktop Entry]\nType=Application\nName=Office\nExec=office %%U\nMimeType=text/plain;\n\n[Desktop Action new]\nName=New\nExec=office --new\n' > "$work/sys/applications/office.desktop"
printf '[Desktop Entry]\nType=Application\nName=Office (mine)\nExec=office --mine\n' > "$apps/office.desktop"
bash "$scripts/remove-entry.sh" office >/dev/null 2>&1
check "an override of an installed entry leaves a hidden copy" grep -qxF "NoDisplay=true" "$apps/office.desktop"
check "the hidden copy is the installed entry (still opens files)" bash -c '[ "$(sed -n "s/^Exec=//p" "$1" | head -n1)" = "office %U" ] && grep -qxF "MimeType=text/plain;" "$1"' _ "$apps/office.desktop"
check "NoDisplay goes in the main section only" bash -c '[ "$(grep -c "^NoDisplay=" "$1")" = 1 ]' _ "$apps/office.desktop"
check "the user's override is in the trash" grep -qxF "Exec=office --mine" "$HOME/trash/office.desktop"

echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
