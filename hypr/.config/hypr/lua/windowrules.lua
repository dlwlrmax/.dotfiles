-- ──────────────────────────────────────────────
-- Workspace assignments
-- ──────────────────────────────────────────────
local ws = {
  { pat = "^(google-chrome)$",                        id = 1 },
  { pat = "^(Chromium)$",                             id = 2 },
  { pat = "^(Lark|Ferdium||ferdium)$",                id = 3 },
  { pat = "^(Code)$",                                 id = 4 },
  { pat = "DBeaver",                                  id = 5 },
  { pat = "Dbeaver",                                  id = 5 },
  { pat = "^(Postman|yaak-app|bruno)$",               id = 6 },
  { pat = "^(Spotify)$",                              id = 7 },
  { pat = "^(zen-beta|zen|com.mitchellh.ghostty)$",   id = 10 },
}
for _, v in ipairs(ws) do
  hl.window_rule({ match = { class = v.pat }, workspace = v.id })
end

-- ──────────────────────────────────────────────
-- Float rules
-- ──────────────────────────────────────────────

-- Simple float-only apps
local float_apps = {
  "nemo", "com.stremio.stremio", "stremio-enhanced",
  "org.qbittorrent.qBittorrent", "git-cola", "vesktop",
  "steam", "org.kde.dolphin", "org.kde.audiotube",
  "thunar", "Thunar", "org.gnome.Nautilus",
  "blueman-manager", "org.kde.kdeconnect.app",
  "com.gabm.satty", "org.pulseaudio.pavucontrol",
  "org.quickshell", "waypaper"
}
hl.window_rule({
  match = { class = string.format("^(%s)$", table.concat(float_apps, "|")) },
  float = true,
})
hl.window_rule({ match = { title = "^(Library)$" }, float = true })

-- Float + sizing
hl.window_rule({ match = { class = "^(Chromium|Google-chrome|Navicat)$" }, min_size = "800 600" })
hl.window_rule({
  name = "mission-center",
  match = { class = "^(io.missioncenter.MissionCenter)$" },
  float = true, min_size = "800 70%",
})
hl.window_rule({
  name = "google-chrome",
  match = { class = "google-chrome" },
  float = true, max_size = "1874 990",
})

-- Float + position/size
hl.window_rule({
  name = "nextcloud",
  match = { class = "com.nextcloud.desktopclient.nextcloud" },
  float = true, move = "monitor_w-500 35", size = "500 400",
})
hl.window_rule({
  name = "chat-gpt",
  match = { title = "(.*chat.openai.com.*)" },
  float = true, size = "500 50%", move = "20 70",
})
hl.window_rule({
  name = "file-manager",
  match = { class = "^(xdg-desktop-portal-gtk)$" },
  float = true, size = "960 680", rounding = 18,
})

-- ──────────────────────────────────────────────
-- Picture-in-Picture
-- ──────────────────────────────────────────────
local pip_position = "40 760"
hl.window_rule({
  match = { class = "mpv" },
  monitor = "HDMI-A-1", float = true,
  move = pip_position, size = "500 280",
})
hl.window_rule({
  match = { title = "^(Picture[- ]?in[- ]?[Pp]icture)$" },
  monitor = "HDMI-A-1", float = true,
  move = pip_position, size = "500 280",
  dim_around = false
})

-- ──────────────────────────────────────────────
-- Chrome popups
-- ──────────────────────────────────────────────
hl.window_rule({ match = { title = "^(chromium-browser|Hình ảnh|Bitwarden)$" }, float = true })
hl.window_rule({ match = { title = "^(chromium-browser)$" }, pin = true })
hl.window_rule({ match = { title = "^(Clipman)$" }, size = "100 20" })

-- ──────────────────────────────────────────────
-- Terminal opacity
-- ──────────────────────────────────────────────
hl.window_rule({ match = { class = "^(org.wezfurlong.wezterm)$" },       opacity = 0.95 })
hl.window_rule({ match = { class = "^(com.mitchellh.ghostty|kitty)$" },  opacity = 0.85 })

-- ──────────────────────────────────────────────
-- Misc window rules
-- ──────────────────────────────────────────────
hl.window_rule({ match = { class = "^(fcitx)$" }, pseudo = true })
hl.window_rule({ match = { class = "^()$", title = "^()$" }, no_blur = true })

hl.window_rule({
  match = { xwayland = true, float = true, title = ".*(drag|Drag).*" },
  no_focus = true,
})

hl.window_rule({
  match = { class = "^(firefox|zen|zen-beta)$", title = "^(Save File)$" },
  float = true, center = true,
})

hl.window_rule({
  name = "dbeaver-popups",
  match = { class = "^DBeaver$", float = true },
  dim_around = true, size = "(monitor_w*0.65) (monitor_h*0.75)", center = true,
})

-- ──────────────────────────────────────────────
-- Layer rules
-- ──────────────────────────────────────────────

-- Quickshell panel bar
hl.layer_rule({ match = { namespace = "^quickshell-bar$" }, ignore_alpha = 0.4 })

-- Notification overlays
hl.layer_rule({ match = { namespace = "^(notifications)$" },     blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "^(swaync-.*)$" },         blur = true, ignore_alpha = 0.5 })

-- DMS control center
hl.layer_rule({
  name = "control-center",
  animation = "slide right",
  match = { namespace = "dms:control-center" },
})

-- DMS overlay panels
hl.layer_rule({
  name = "dms-overlay",
  blur = true, ignore_alpha = 0, dim_around = true,
  match = { namespace = "dms:(color-picker|clipboard|spotlight|settings)" },
})
