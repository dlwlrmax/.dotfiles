-- ──────────────────────────────────────────────
-- Hymission: Mission Control style overview (Hyprland plugin)
-- https://github.com/gfhdhytghd/hymission — installed via hyprpm.
-- ──────────────────────────────────────────────
-- The plugin is loaded asynchronously (`hyprpm reload` in autostart.lua), so
-- the first config pass runs without it. Once loaded the plugin reloads the
-- config and this file registers everything. Every plugin access is guarded:
-- an unguarded `hl.plugin.hymission.*` errors and aborts the rest of the config.

local vars = require("lua/variables")
local mainMod = vars.mainMod

local hm = hl.plugin and hl.plugin.hymission
if not hm then
  -- Plugin not loaded (yet). On login it loads asynchronously and reloads the
  -- config, replacing these. If it is still missing later (e.g. needs
  -- `hyprpm update` after a Hyprland upgrade), keep basic switching alive.
  hl.bind("ALT + TAB", hl.dsp.window.cycle_next())
  hl.bind("ALT + SHIFT + TAB", hl.dsp.window.cycle_next({ prev = true }))
  hl.bind(mainMod .. " + TAB", hl.dsp.focus({ monitor = "+1" }))
  pcall(hl.timer, function()
    if not (hl.plugin and hl.plugin.hymission) then
      pcall(hl.notification.create, {
        text = "hymission not loaded: run `hyprpm update` (Alt+Tab falls back to basic cycling)",
        timeout = 10000,
      })
    end
  end, { timeout = 20000, type = "oneshot" })
  return
end

-- Every bind that opens the overview tells pippeek first, so the PIP
-- hover-peek can't fire on previews or on the exit cursor warp.
local pippeek = require("lua/pippeek")
local function opening(fn, kind)
  return function()
    pippeek.overview_open(kind)
    fn()
  end
end

-- The switcher commits on Left Alt release (switch_release_key). `ALT + TAB`
-- also matches Right Alt/AltGr, whose release would never commit, so only
-- start it with Left Alt held.
local function left_alt(fn)
  return function()
    local ok, down = pcall(hl.is_key_down, "Alt_L")
    if ok and down then fn() end
  end
end

-- Unknown keys make hl.config throw; keep a bad key from killing the binds.
local ok, err = pcall(hl.config, {
  plugin = {
    hymission = {
      -- ALT+TAB is the task switcher: hold Alt, tap Tab to step, release Alt
      -- to focus the selection. Switch mode only affects `toggle`, so every
      -- other bind below uses `open` (a toggle session would wait for Alt).
      toggle_switch_mode = 1,
      switch_toggle_auto_next = 1,
      switch_release_key = "Alt_L",

      -- Layout: Apple-like placement (keeps windows near their real position).
      layout_engine = "natural",
      outer_padding_top = 64, -- clear the quickshell bar
      show_focus_indicator = 1, -- visible selection while stepping with Tab
      focus_selected_color = "rgba(33ccffee)", -- matches active_border

      -- iGPU (UHD 630): no backdrop blur, just a dim.
      backdrop_blur = 0,
      backdrop_color = "rgba(00000066)",

      close_button_enabled = 1,
    },
  },
})
if not ok then
  pcall(hl.notification.create, { text = "hymission config: " .. tostring(err), timeout = 8000 })
end

-- Alt+Tab switcher (replaces the quickshell alttab overlay)
hl.bind("ALT + TAB", left_alt(opening(function() hm.toggle() end, "switch")))
hl.bind("ALT + SHIFT + TAB", left_alt(opening(function() hm.toggle("reverse") end, "switch")))

-- Overview: Tab/Shift+Tab step, Return activates, Escape closes.
hl.bind(mainMod .. " + TAB", opening(function() hm.open() end))
hl.bind(mainMod .. " + CTRL + TAB", function()
  hm.close()
  pippeek.overview_close()
end)
-- Current workspace only / every workspace
hl.bind(mainMod .. " + C", opening(function() hm.open("onlycurrentworkspace") end))
hl.bind(mainMod .. " + A", opening(function() hm.open("forceall") end))
