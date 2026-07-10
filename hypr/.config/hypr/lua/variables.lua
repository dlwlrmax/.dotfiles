-- Shared constants — single source of truth for all modules.
-- Consume via: local vars = require("lua/variables")
local M = {}

M.terminal    = "ghostty"
M.mainMod     = "SUPER"
M.mainModS    = M.mainMod .. " + SHIFT"
-- M.fileManager = "dolphin"
M.fileManager = "Thunar"


-- Env vars, general, decoration, input, misc, xwayland, cursor

-- XDG Desktop Portal
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Fcitx 5
hl.env("GTK_IM_MODULE", "fcitx")
hl.env("ADW_DISABLE_PORTAL", "1")
hl.env("GTK_THEME", "Orchis-Dark")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("SDL_IM_MODULE", "fcitx")

-- QT
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")

-- GDK
hl.env("GDK_SCALE", "1")

-- Toolkit Backend
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("CLUTTER_BACKEND", "wayland")

-- Mozilla
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- Cursor size
hl.env("XCURSOR_SIZE", "20")
hl.env("HYPRCURSOR_SIZE", "20")

-- Default terminal
hl.env("TERMINAL", "ghostty")

-- Ozone / Electron
hl.env("OZONE_PLATFORM", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.config({
  general = {
    border_size = 3,
    col = {
      active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
      inactive_border = "rgba(595959aa)",
    },
    layout = "dwindle",
    modal_parent_blocking = true,
    gaps_out = 10
  },

  decoration = {
    rounding = 5,
    active_opacity = 1,
    inactive_opacity = 1,
    fullscreen_opacity = 1,

    blur = {
      enabled = true,
      size = 3,
      passes = 2,
      xray = false,
      ignore_opacity = true,
      new_optimizations = true,
      noise = 0.02,
      contrast = 1,
      vibrancy = 0.2,
      vibrancy_darkness = 0.3,
    },

    dim_modal = true,
    dim_around = 0.35,

    shadow = {
      enabled = true,
      range = 10,
      render_power = 2,
      color = "0x33000000",
    },
  },

  animations = {
    enabled = true,
  },

  input = {
    kb_layout = "us",
    kb_variant = "",
    kb_model = "",
    kb_options = "",
    kb_rules = "",
    follow_mouse = 1,
    repeat_rate = 20,
    repeat_delay = 200,
    touchpad = {
      natural_scroll = false,
    },
  },

  xwayland = {
    force_zero_scaling = true,
  },

  cursor = {
    no_hardware_cursors = false,
    inactive_timeout = 5.0,
  },

  misc = {
    disable_splash_rendering = true,
  },
})

return M
