#!/bin/bash
# System updates module for waybar
# Shows count of pending updates for pacman, AUR, and flatpak
# Icon changes color when updates available
# Click to open update terminal

set -e

# Count pacman updates (official repos)
get_pacman_count() {
    if command -v checkupdates &>/dev/null; then
        checkupdates 2>/dev/null | wc -l || echo "0"
    else
        echo "0"
    fi
}

# Count AUR updates
get_aur_count() {
    if command -v paru &>/dev/null; then
        paru -Qua 2>/dev/null | wc -l || echo "0"
    elif command -v yay &>/dev/null; then
        yay -Qua 2>/dev/null | wc -l || echo "0"
    else
        echo "0"
    fi
}

# Count flatpak updates
get_flatpak_count() {
    if command -v flatpak &>/dev/null; then
        flatpak remote-ls --updates 2>/dev/null | wc -l || echo "0"
    else
        echo "0"
    fi
}

# Get all counts
PACMAN_COUNT=$(get_pacman_count)
AUR_COUNT=$(get_aur_count)
FLATPAK_COUNT=$(get_flatpak_count)

# Calculate total
TOTAL=$((PACMAN_COUNT + AUR_COUNT + FLATPAK_COUNT))

# Build tooltip array
tooltip_parts=()
if [ "$PACMAN_COUNT" -gt 0 ]; then
    tooltip_parts+=("Pacman: $PACMAN_COUNT")
fi
if [ "$AUR_COUNT" -gt 0 ]; then
    tooltip_parts+=("AUR: $AUR_COUNT")
fi
if [ "$FLATPAK_COUNT" -gt 0 ]; then
    tooltip_parts+=("Flatpak: $FLATPAK_COUNT")
fi

if [ ${#tooltip_parts[@]} -eq 0 ]; then
    TOOLTIP="No updates available"
else
    TOOLTIP="Updates available: ${tooltip_parts[*]}"
fi

# Determine class (for CSS styling)
if [ "$TOTAL" -eq 0 ]; then
    CLASS="no-updates"
else
    CLASS="updates-available"
fi

# Output JSON for waybar
cat <<EOF
{"text": "$TOTAL ", "tooltip": "$TOOLTIP", "class": "$CLASS", "alt": "$PACMAN_COUNT|$AUR_COUNT|$FLATPAK_COUNT"}
EOF
