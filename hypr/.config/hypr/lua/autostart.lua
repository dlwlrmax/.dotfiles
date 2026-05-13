local terminal = "ghostty"

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("waybar")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("waypaper --restore")
    hl.exec_cmd("zen-browser")
    hl.exec_cmd("sleep 5 && " .. terminal)
    hl.exec_cmd("swaync")
    hl.exec_cmd("walker --gapplication-service")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("nohup easyeffects --gapplication-service")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("fcitx5 -d")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("systemctl --user restart xdg-desktop-portal.service")
    hl.exec_cmd("sleep 10 && /usr/libexec/xdg-desktop-portal-hyprland -r")
    hl.exec_cmd("sleep 60 && ferdium")
    hl.exec_cmd("sleep 10 && google-chrome-stable --disable-features=WaylandWpColorManagerV1")
    hl.exec_cmd("sleep 120 && nextcloud --background")

    -- Clipboard
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("sh -c 'cliphist wipe'")

    -- Cursor
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 20")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'")

    -- Color scheme - dark mode
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme Fluent-Dark")
    hl.exec_cmd("hyprctl reload")
end)
