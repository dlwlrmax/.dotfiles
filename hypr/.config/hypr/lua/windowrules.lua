local pip_pos = {
  x = 1949,
  y = 769,
}
-- Workspace assignments
hl.window_rule({ match = { class = "^(google-chrome)$" }, workspace = 1 })
hl.window_rule({ match = { class = "^(Chromium)$" }, workspace = 2 })
hl.window_rule({ match = { class = "^(Lark|Ferdium||ferdium)$" }, workspace = 3 })
hl.window_rule({ match = { class = "^(Code)$" }, workspace = 4 })
hl.window_rule({ match = { class = "DBeaver" }, workspace = 5 })
hl.window_rule({ match = { class = "Dbeaver" }, workspace = 5 })
hl.window_rule({ match = { class = "^(Postman|yaak-app|bruno)$" }, workspace = 6 })
hl.window_rule({ match = { class = "^(Spotify)$" }, workspace = 7 })
hl.window_rule({ match = { class = "^(zen-beta|zen|com.mitchellh.ghostty)$" }, workspace = 10 })

-- Size & Floating Rules
hl.window_rule({ match = { class = "^(Chromium|Google-chrome|Navicat)$" }, min_size = "800 600" })
hl.window_rule({
  match = {
    class = "^(nemo|com.stremio.stremio|stremio-enhanced|org.qbittorrent.qBittorrent|git-cola|vesktop|steam|org.kde.dolphin|org.kde.audiotube|thunar|Thunar|org.gnome.Nautilus)$",
  },
  float = true,
})
hl.window_rule({ match = { title = "^(Library)$" }, float = true })

-- Nextcloud
hl.window_rule({
  name = "nextcloud",
  match = { class = "com.nextcloud.desktopclient.nextcloud" },
  float = true,
  move = "monitor_w-500 35",
  size = "500 400",
})

-- Google Chrome float
hl.window_rule({
  name = "google-chrome",
  match = { class = "google-chrome" },
  float = true,
})

-- Blueman
hl.window_rule({
  name = "blueman-manager",
  match = { class = "blueman-manager" },
  float = true,
})

-- KDE Connect
hl.window_rule({
  name = "org.kde.kdeconnect.app",
  match = { class = "org.kde.kdeconnect.app" },
  float = true,
})

-- mpv
hl.window_rule({
  name = "mpv",
  match = { class = "mpv" },
  float = true,
  pin = true,
  no_follow_mouse = true,
  no_initial_focus = true,
  size = "500 280",
  content = "video",
  monitor = 1,
  move = pip_pos.x .. " " .. pip_pos.y,
})

-- Satty
hl.window_rule({
  name = "satty",
  match = { class = "^(com.gabm.satty)$" },
  float = true,
})

-- Pavucontrol
hl.window_rule({
  name = "pavu-control",
  match = { class = "^(org.pulseaudio.pavucontrol)$" },
  float = true,
})

-- MissionCenter
hl.window_rule({
  name = "io.missioncenter.MissionCenter",
  match = { class = "^(io.missioncenter.MissionCenter)$" },
  float = true,
  min_size = "800 70%",
})

-- Zen Picture-in-Picture
hl.window_rule({
  name = "zen-pip",
  match = { title = "^(Picture in picture|Picture-in-Picture|Picture in Picture)$" },
  float = true,
  pin = true,
  no_follow_mouse = true,
  no_initial_focus = true,
  size = "500 280",
  content = "video",
  monitor = 1,
  move = pip_pos.x .. " " .. pip_pos.y,
})
hl.window_rule({ match = { title = "^(Picture[- ]?in[- ]?[Pp]icture)$" }, dim_around = false })

-- Chrome popups
hl.window_rule({ match = { title = "^(chromium-browser|Hình ảnh|Bitwarden)$" }, float = true })
hl.window_rule({ match = { title = "^(chromium-browser)$" }, pin = true })
hl.window_rule({ match = { title = "^(Clipman)$" }, size = "100 20" })

-- Terminal opacity
hl.window_rule({ match = { class = "^(org.wezfurlong.wezterm)$" }, opacity = 0.95 })
hl.window_rule({ match = { class = "^(com.mitchellh.ghostty|kitty)$" }, opacity = 0.85 })

-- ChatGPT
hl.window_rule({
  name = "chat-gpt",
  match = { title = "(.*chat.openai.com.*)" },
  float = true,
  size = "500 50%",
  move = "20 70",
})

-- Fcitx
hl.window_rule({ match = { class = "^(fcitx)$" }, pseudo = true })
hl.window_rule({ match = { class = "^()$", title = "^()$" }, no_blur = true })
-- File manager portal
hl.window_rule({
  name = "file-manager",
  match = { class = "^(xdg-desktop-portal-gtk)$" },
  float = true,
  size = "960 680",
  rounding = 18,
})

-- XWayland drag windows
hl.window_rule({
  match = { xwayland = true, float = true, title = ".*(drag|Drag).*" },
  no_focus = true,
})

-- Browser save dialogs
hl.window_rule({
  match = { class = "^(firefox|zen|zen-beta)$", title = "^(Save File)$" },
  float = true,
  center = true,
})

-- DBeaver popups
hl.window_rule({
  name = "dbeaver-popups",
  match = { class = "^DBeaver$", float = true },
  dim_around = true,
  size = "(monitor_w*0.65) (monitor_h*0.75)",
  center = true,
})

-- Quickshell / DMS
hl.window_rule({
  name = "dms",
  match = { class = "^(org.quickshell)$" },
  float = true,
})

------------------------
---- LAYER RULES ----
------------------------

-- Quickshell panel bar
hl.layer_rule({ match = { namespace = "^quickshell-bar$" }, ignore_alpha = 0.4 })

-- Mako notifications
hl.layer_rule({ match = { namespace = "^(notifications)$" }, blur = true })
hl.layer_rule({ match = { namespace = "^(notifications)$" }, ignore_alpha = 0.5 })

-- SwayNC notifications (legacy)
hl.layer_rule({ match = { namespace = "^(swaync-.*)$" }, blur = true })
hl.layer_rule({ match = { namespace = "^(swaync-.*)$" }, ignore_alpha = 0.5 })

-- DMS control center
hl.layer_rule({
  name = "control-center",
  animation = "slide right",
  match = { namespace = "dms:control-center" },
})

-- DMS color picker / clipboard / spotlight / settings
hl.layer_rule({
  name = "color-picker",
  blur = true,
  ignore_alpha = 0,
  match = { namespace = "dms:(color-picker|clipboard|spotlight|settings)" },
})

hl.layer_rule({
  name = "dms-dim",
  dim_around = true,
  match = { namespace = "dms:(color-picker|clipboard|spotlight|settings)" },
})
