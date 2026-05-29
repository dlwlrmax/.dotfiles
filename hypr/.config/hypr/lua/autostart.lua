local vars = require("lua/variables")
local terminal = vars.terminal

-- Launch one or more commands, optionally with a startup delay.
-- Each command gets its own delayed subprocess (matches `sleep N && cmd` semantics).
local function launch(delay, ...)
  local cmds = { ... }
  for _, cmd in ipairs(cmds) do
    if delay > 0 then
      hl.exec_cmd("sleep " .. delay .. " && " .. cmd)
    else
      hl.exec_cmd(cmd)
    end
  end
end

hl.on("hyprland.start", function()
  -- ═══════════════════════════════════════════════════════════
  -- TIER 1: environment, auth, theming, input — load first
  -- ═══════════════════════════════════════════════════════════
  launch(0,
    "dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP",
    "gnome-keyring-daemon --start --components=secrets",
    "systemctl --user start hyprpolkitagent",
    "fcitx5 -d",
    "hyprctl setcursor Bibata-Modern-Ice 20",
    "gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'",
    "gsettings set org.gnome.desktop.interface color-scheme prefer-dark",
    "gsettings set org.gnome.desktop.interface gtk-theme Fluent-Dark",
    "hyprctl reload"
  )

  -- ═══════════════════════════════════════════════════════════
  -- TIER 2: core desktop — bar, wallpaper, notifications, portals
  -- ═══════════════════════════════════════════════════════════
  launch(0,
    "quickshell",
    "mako",
    "hyprpaper",
    "waypaper --restore",
    "walker --gapplication-service",
    "hypridle",
    "systemctl --user restart xdg-desktop-portal.service",
    "wl-paste --watch cliphist store"
  )

  -- ═══════════════════════════════════════════════════════════
  -- TIER 3: utilities, portal backend, cleanup (slight delay)
  -- ═══════════════════════════════════════════════════════════
  launch(2,
    "/usr/libexec/xdg-desktop-portal-hyprland -r",
    "blueman-applet",
    "nohup easyeffects --gapplication-service"
  )
  launch(3, "sh -c 'cliphist wipe'")

  -- ═══════════════════════════════════════════════════════════
  -- TIER 4: user apps — deferred to keep desktop responsive
  -- ═══════════════════════════════════════════════════════════
  launch(5,  terminal)
  launch(6,  "zen-browser")
  launch(15, "google-chrome-stable --disable-features=WaylandWpColorManagerV1")
  launch(60, "ferdium")
  launch(120, "nextcloud --background")
end)
