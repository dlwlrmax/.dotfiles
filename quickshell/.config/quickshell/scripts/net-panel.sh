#!/bin/bash
# Wrapper for ~/.cargo/bin/net-panel — falls back gracefully if binary missing
set -e

BIN="$HOME/.cargo/bin/net-panel"

if [ -x "$BIN" ]; then
    exec "$BIN" "$@"
fi

# Return valid empty JSON for "info" subcommand
case "${1:-}" in
    info) echo '{"iface":"","ips":[],"dns_servers":[],"tailscale":null}' ;;
    *)    echo '{}' ;;
esac
