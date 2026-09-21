#!/bin/bash
# Wrapper for ~/.cargo/bin/sys-stats — falls back gracefully if binary missing
set -e

BIN="$HOME/.cargo/bin/sys-stats"

if [ -x "$BIN" ]; then
    exec "$BIN"
fi

exec bash "$(dirname "$0")/sys-stats.sh"
