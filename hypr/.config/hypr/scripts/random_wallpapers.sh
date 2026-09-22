#!/bin/bash

# Check if a file argument was provided
if [ -z "$1" ]; then
    echo "Error: Please provide a wallpaper file as an argument."
    exit 1
fi

# Check if the file exists
if [ ! -f "$1" ]; then
    echo "Error: File not found: $1"
    exit 1
fi

# Path to your hyprpaper configuration file
hyprpaper_config_file="$HOME/.config/hypr/hyprpaper.conf"

# Resolve absolute path and validate extension before touching the config
path="$(realpath -- "$1")"
case "${path,,}" in
    *.jpg|*.jpeg|*.png|*.webp|*.bmp) ;;
    *)
        echo "Error: unsupported wallpaper file type: $1"
        exit 1
        ;;
esac

# Rewrite the config atomically: keep every line except preload/wallpaper, then append the new ones
tmp_file="$(mktemp "${hyprpaper_config_file}.XXXXXX")" || exit 1
grep -v -e '^preload = ' -e '^wallpaper = ' "$hyprpaper_config_file" > "$tmp_file" || true
printf 'preload = %s\nwallpaper = ,%s\n' "$path" "$path" >> "$tmp_file"
# Keep the config's existing permissions (mktemp would otherwise leave it 0600).
chmod --reference="$hyprpaper_config_file" "$tmp_file" 2>/dev/null || chmod 644 "$tmp_file"
mv "$tmp_file" "$hyprpaper_config_file"

# Reload hyprpaper
killall -e hyprpaper & 
sleep 1; 
hyprpaper &

# Let the user know it's done
echo "Wallpaper settings in hyprpaper.conf updated successfully."
