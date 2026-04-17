#!/bin/bash
# Opens terminal to run system updates
# Called when clicking on the system-updates module

set -e

# Get the terminal emulator (prefer kitty or alacritty)
get_terminal() {
    if command -v kitty &>/dev/null; then
        echo "kitty"
    elif command -v alacritty &>/dev/null; then
        echo "alacritty"
    elif command -v wezterm &>/dev/null; then
        echo "wezterm"
    elif command -v foot &>/dev/null; then
        echo "foot"
    else
        echo ""
    fi
}

TERMINAL=$(get_terminal)

# Create update command
UPDATE_CMD=""

# Add pacman updates
if command -v checkupdates &>/dev/null && [ "$(checkupdates 2>/dev/null | wc -l)" -gt 0 ]; then
    UPDATE_CMD+="echo '=== Pacman Updates ===' && sudo pacman -Syu"
fi

# Add AUR updates
if command -v paru &>/dev/null && [ "$(paru -Qua 2>/dev/null | wc -l)" -gt 0 ]; then
    if [ -n "$UPDATE_CMD" ]; then
        UPDATE_CMD+=" && "
    fi
    UPDATE_CMD+="echo '=== AUR Updates ===' && paru -Sua"
elif command -v yay &>/dev/null && [ "$(yay -Qua 2>/dev/null | wc -l)" -gt 0 ]; then
    if [ -n "$UPDATE_CMD" ]; then
        UPDATE_CMD+=" && "
    fi
    UPDATE_CMD+="echo '=== AUR Updates ===' && yay -Sua"
fi

# Add flatpak updates
if command -v flatpak &>/dev/null && [ "$(flatpak remote-ls --updates 2>/dev/null | wc -l)" -gt 0 ]; then
    if [ -n "$UPDATE_CMD" ]; then
        UPDATE_CMD+=" && "
    fi
    UPDATE_CMD+="echo '=== Flatpak Updates ===' && flatpak update"
fi

if [ -z "$UPDATE_CMD" ]; then
    UPDATE_CMD="echo 'No updates available' && read -n 1 -s -r -p 'Press any key to exit...'"
else
    UPDATE_CMD+=" && read -n 1 -s -r -p 'Updates complete. Press any key to exit...'"
fi

# Open terminal with update command
if [ -n "$TERMINAL" ]; then
    case "$TERMINAL" in
        kitty)
            kitty --hold -e bash -c "$UPDATE_CMD" &
            ;;
        alacritty)
            alacritty --hold -e bash -c "$UPDATE_CMD" &
            ;;
        wezterm)
            wezterm start -- bash -c "$UPDATE_CMD" &
            ;;
        foot)
            foot bash -c "$UPDATE_CMD" &
            ;;
    esac
else
    # Fallback: notify user no terminal found
    notify-send "System Updates" "No supported terminal found. Please install kitty, alacritty, wezterm, or foot."
fi
