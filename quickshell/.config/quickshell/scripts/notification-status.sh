#!/bin/bash
# Notification status for Quickshell
# Outputs: COUNT DND(true/false)

count=$(swaync-client --skip-wait --count 2>/dev/null || echo "0")
dnd=$(swaync-client --skip-wait --get-dnd 2>/dev/null || echo "false")

echo "$count $dnd"
