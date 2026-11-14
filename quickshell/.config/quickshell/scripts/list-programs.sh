#!/bin/bash
# Folder listing for the launcher's file picker (`+ ~/some/folder/`).
#   list-programs.sh <dir>   prints "ok<TAB><dir>" (the argument as given, so the
#                            caller can tell which request this answers), then one
#                            line per sub-folder ("d<TAB>name") and per .exe /
#                            .AppImage file ("f<TAB>name").
#                            Prints "fail<TAB><dir>" when the folder can't be opened.
#                            Names with a line break in them are left out: they
#                            can't be told apart from two lines.
arg="${1:-}"
dir="${arg:-$HOME}"
dir="${dir/#\~/$HOME}"
cd -- "$dir" 2>/dev/null || { printf 'fail\t%s\n' "$arg"; exit 0; }
printf 'ok\t%s\n' "$arg"
find -L . -mindepth 1 -maxdepth 1 ! -name $'*\n*' \( \
  \( -type d -printf 'd\t%f\n' \) -o \
  \( -type f \( -iname '*.exe' -o -iname '*.appimage' \) -printf 'f\t%f\n' \) \) 2>/dev/null
exit 0
