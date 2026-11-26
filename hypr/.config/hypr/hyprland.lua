-- Hyprland 0.55 Lua config
-- https://wiki.hypr.land/Configuring/Start/

-- Modules register keywords via side effects on require. The per-machine
-- modules (lua/monitors, lua/workspaces, lua/local) are gitignored and are
-- seeded from *.lua.example by bootstrap.sh; pcall keeps a fresh machine's
-- session alive when one is missing or broken (same silent-fallback
-- convention autostart.lua and windowrules.lua use for lua/local) — the
-- module simply contributes nothing and Hyprland auto-configures monitors.
pcall(require, "lua/variables")
pcall(require, "lua/layout")
pcall(require, "lua/windowrules")
pcall(require, "lua/pippeek")
pcall(require, "lua/floatsize")
pcall(require, "lua/gaming")
pcall(require, "lua/poefocus")
pcall(require, "lua/keybinds")
pcall(require, "lua/hymission")
pcall(require, "lua/autostart")
pcall(require, "lua/workspaces")
pcall(require, "lua/monitors")
