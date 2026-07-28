#!/bin/bash
# Wrapper for ~/.cargo/bin/net-stats — falls back gracefully if binary missing
set -e

BIN="$HOME/.cargo/bin/net-stats"

if [ -x "$BIN" ]; then
    exec "$BIN"
else
    echo "--|--"
fi
