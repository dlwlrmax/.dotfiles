-- ──────────────────────────────────────────────
-- Workspace assignments
-- ──────────────────────────────────────────────
local ok, local_cfg = pcall(require, "lua/local")
local overrides = ok and local_cfg or {}
local ws = {
  { pat = "^(Chromium)$", id = 2 },
  { pat = "^(Lark|Ferdium||ferdium)$", id = 3 },
  { pat = "^(Code|code-oss)$", id = 4 },
  { pat = "[Dd][Bb]eaver|tabularis", id = 5 },
  { pat = "^(Postman|yaak-app|bruno)$", id = 6 },
  { pat = "^(Spotify)$", id = 7 },
  { pat = "^(zen-beta|zen|com.mitchellh.ghostty)$", id = overrides.zen_ws or 10 },
}
for _, v in ipairs(ws) do
  hl.window_rule({ match = { class = v.pat }, workspace = v.id })
end
local pip_position = "-570 600"
local pip_size = "543 306"

-- ──────────────────────────────────────────────
-- Float rules
-- ──────────────────────────────────────────────

-- Simple float-only apps
local float_apps = {
  "nemo",
  "org.qbittorrent.qBittorrent",
  "git-cola",
  "steam",
  "org.kde.audiotube",
  "org.gnome.Nautilus",
  "blueman-manager",
  "org.kde.kdeconnect.app",
  "com.gabm.satty",
  "org.pulseaudio.pavucontrol",
  "org.quickshell",
  "waypaper",
  "org.kde.ark",
  "font-manager",
  "code-oss",
}
hl.window_rule({
  match = { class = string.format("^(%s)$", table.concat(float_apps, "|")) },
  float = true,
})
hl.window_rule({ match = { class = "^(Dictionary)$" }, float = true, center = true, workspace = 2 })
hl.window_rule({ match = { title = "^(Library)$" }, float = true })
hl.window_rule({ match = { title = ".*(Tài khoản Google|Google Account|accounts\\.google\\.com).*" }, float = true })
hl.window_rule({ match = { title = ".*Tailscale.*" }, float = true })
hl.window_rule({
  match = { class = "^(vesktop)$" },
  float = true,
  workspace = 6,
})
hl.window_rule({
  match = { class = "^(google-chrome)$" },
  workspace = 1,
})
hl.window_rule({
  match = { class = "^(obsidian)$" },
  float = true,
  size = "(monitor_w*0.65) (monitor_h*0.75)",
  center = true,
  workspace = 2,
  focus_on_activate = true,
})
hl.window_rule({
  match = { class = "^([Tt]hunar|[Oo]rg.gnome.Nautilus|[Oo]rg.kde.dolphin)$" },
  float = true,
  size = "(monitor_w*0.65) (monitor_h*0.75)",
  center = true,
  workspace = 2,
})

-- Float + sizing
hl.window_rule({ match = { class = "^(Chromium|Google-chrome|Navicat)$" }, min_size = "800 600" })
hl.window_rule({
  name = "mission-center",
  match = { class = "^(io.missioncenter.MissionCenter)$" },
  float = true,
  min_size = "800 70%",
})

-- Float + position/size
hl.window_rule({
  name = "nextcloud",
  match = { class = "com.nextcloud.desktopclient.nextcloud" },
  float = true,
  move = "monitor_w-500 35",
  size = "500 400",
})
hl.window_rule({
  name = "chat-gpt",
  match = { title = "(.*chat.openai.com.*)" },
  float = true,
  size = "500 50%",
  move = "20 70",
})
hl.window_rule({
  name = "file-manager",
  match = { class = "^(xdg-desktop-portal-gtk)$" },
  float = true,
  size = "960 680",
  rounding = 18,
})

-- ──────────────────────────────────────────────
-- Picture-in-Picture (pinned float on HDMI-A-1)
-- ──────────────────────────────────────────────
hl.window_rule({
  match = { class = "mpv" },
  monitor = "HDMI-A-1",
  float = true,
  pin = true,
  move = pip_position,
  size = pip_size,
})
hl.window_rule({
  match = { title = "(?i)picture.*picture" },
  monitor = "HDMI-A-1",
  float = true,
  pin = true,
  move = pip_position,
  size = pip_size,
  dim_around = false,
})
hl.window_rule({
  match = { class = "^(stremio-enhanced|com.stremio.Stremio)$" },
  monitor = "HDMI-A-1",
  float = true,
  pin = true,
  move = pip_position,
  size = pip_size,
  dim_around = false,
})

-- Fullscreen border highlight
hl.window_rule({
  match = { fullscreen = true },
  border_color = "rgba(255, 19, 0, 0.8)",
})

hl.window_rule({
  match = { float = true },
  border_color = "rgba(102, 57, 173, 0.8)",
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
hl.window_rule({ match = { class = "^(org.wezfurlong.wezterm)$" }, opacity = 0.95 })
hl.window_rule({ match = { class = "^(com.mitchellh.ghostty|kitty)$" }, opacity = 0.85 })

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
  float = true,
  center = true,
})

hl.window_rule({
  name = "dbeaver-popups",
  match = { class = "^DBeaver$", float = true },
  dim_around = true,
  size = "(monitor_w*0.65) (monitor_h*0.75)",
  center = true,
})

-- ──────────────────────────────────────────────
-- Layer rules
-- ──────────────────────────────────────────────

-- Quickshell panel bar
hl.layer_rule({ match = { namespace = "^quickshell-bar$" }, ignore_alpha = 0.4 })

-- Notification overlays
hl.layer_rule({ match = { namespace = "^(notifications)$" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "^(swaync-.*)$" }, blur = true, ignore_alpha = 0.5 })

-- DMS control center
hl.layer_rule({
  name = "control-center",
  animation = "slide right",
  match = { namespace = "dms:control-center" },
})

-- DMS overlay panels
hl.layer_rule({
  name = "dms-overlay",
  blur = true,
  ignore_alpha = 0,
  dim_around = true,
  match = { namespace = "dms:(color-picker|clipboard|spotlight|settings)" },
})
