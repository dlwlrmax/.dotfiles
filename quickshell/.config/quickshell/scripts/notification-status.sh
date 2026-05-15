#!/bin/bash
# Notification status for Quickshell (mako)
# Outputs: COUNT DND(true/false)

# Count active notifications
if command -v makoctl &>/dev/null; then
    count=$(makoctl list -j 2>/dev/null | jq -r 'length' 2>/dev/null || echo "0")

    # Check if "dnd" mode is active
    dnd_modes=$(makoctl mode 2>/dev/null || echo "")
    if echo "$dnd_modes" | grep -qw "dnd"; then
        dnd="true"
    else
        dnd="false"
    fi
else
    count="0"
    dnd="false"
fi

echo "$count $dnd"
