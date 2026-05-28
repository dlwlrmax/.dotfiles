local terminal = "ghostty"

hl.on("hyprland.start", function()
    -- ═══════════════════════════════════════════════════════════
    -- CRITICAL: environment, auth, theming, input — load first
    -- ═══════════════════════════════════════════════════════════
    hl.exec_cmd("dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("fcitx5 -d")

    -- Cursor
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 20")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'")

    -- ydotool daemon for mouse scroll
    hl.exec_cmd("systemctl --user start ydotoold")

    -- Color scheme - dark mode
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme Fluent-Dark")

    hl.exec_cmd("hyprctl reload")

    -- ═══════════════════════════════════════════════════════════
    -- HIGH: core desktop — bar, wallpaper, notifications, portals
    -- ═══════════════════════════════════════════════════════════
    hl.exec_cmd("quickshell")
    hl.exec_cmd("mako")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("waypaper --restore")
    hl.exec_cmd("walker --gapplication-service")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("systemctl --user restart xdg-desktop-portal.service")

    -- Clipboard
    hl.exec_cmd("wl-paste --watch cliphist store")

    -- ═══════════════════════════════════════════════════════════
    -- MEDIUM: utilities, portal backend, cleanup (slight delay)
    -- ═══════════════════════════════════════════════════════════
    hl.exec_cmd("sleep 2 && /usr/libexec/xdg-desktop-portal-hyprland -r")
    hl.exec_cmd("sleep 2 && blueman-applet")
    hl.exec_cmd("sleep 2 && nohup easyeffects --gapplication-service")
    hl.exec_cmd("sleep 3 && sh -c 'cliphist wipe'")

    -- ═══════════════════════════════════════════════════════════
    -- LOW: user apps — deferred to keep desktop responsive
    -- ═══════════════════════════════════════════════════════════
    hl.exec_cmd("sleep 6 && zen-browser")
    hl.exec_cmd("sleep 5 && " .. terminal)
    hl.exec_cmd("sleep 15 && google-chrome-stable --disable-features=WaylandWpColorManagerV1")
    hl.exec_cmd("sleep 60 && ferdium")
    hl.exec_cmd("sleep 120 && nextcloud --background")
end)
