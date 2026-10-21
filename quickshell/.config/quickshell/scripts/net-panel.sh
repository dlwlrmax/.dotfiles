#!/bin/bash
# Wrapper for ~/.cargo/bin/net-panel — falls back gracefully if binary missing
set -e

BIN="$HOME/.cargo/bin/net-panel"

if [ -x "$BIN" ]; then
    # info/dns shell out to tailscale, ip and resolvectl; a hung daemon must not block the panel.
    case "${1:-}" in
        speedtest) exec "$BIN" "$@" ;;
        *) exec timeout 8 "$BIN" "$@" ;;
    esac
fi

# Return valid empty JSON for "info" subcommand
case "${1:-}" in
    info) echo '{"iface":"","ips":[],"dns_servers":[],"tailscale":null}' ;;
    *)    echo '{}' ;;
esac
