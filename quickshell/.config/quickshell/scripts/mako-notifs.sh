#!/bin/bash
# Fetch mako notifications as JSON for Quickshell
# Outputs: {"active": [...], "history": [...]}

active=$(makoctl list -j 2>/dev/null || echo '[]')
history=$(makoctl history -j 2>/dev/null || echo '[]')

echo "{\"active\": $active, \"history\": $history}"
