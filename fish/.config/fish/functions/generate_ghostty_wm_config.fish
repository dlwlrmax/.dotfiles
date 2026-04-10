#!/usr/bin/env fish

# Generate WM-specific ghostty config
# Run this from config.fish to set window-decoration based on WM

set -l GHOSTTY_WM_CONFIG "$HOME/.config/ghostty/config.d/wm.conf"

# Ensure config.d directory exists
mkdir -p (dirname $GHOSTTY_WM_CONFIG)

# Check if running under Hyprland
if test "$XDG_CURRENT_DESKTOP" = "Hyprland" -o -n "$HYPRLAND_INSTANCE_SIGNATURE"
    echo "# Auto-generated for Hyprland" > $GHOSTTY_WM_CONFIG
    echo "window-decoration = false" >> $GHOSTTY_WM_CONFIG
else
    echo "# Auto-generated for other WM" > $GHOSTTY_WM_CONFIG
    echo "window-decoration = true" >> $GHOSTTY_WM_CONFIG
end
