#!/bin/bash
# Wrapper for ~/.cargo/bin/sys-stats — falls back gracefully if binary missing
set -e

BIN="$HOME/.cargo/bin/sys-stats"

if [ -x "$BIN" ]; then
    exec "$BIN"
else
    echo '{"cpu":0,"ram":0,"swap":0,"gpu":0,"cpu_temp":0}'
fi
