-- ──────────────────────────────────────────────
-- Media focus cycle (SUPER + S)
-- ──────────────────────────────────────────────
-- current -> Stremio -> mpv -> browser PiP -> previous window
-- Runs in-compositor (replaces scripts/stremio-focus.sh): no bash/jq/hyprctl
-- spawn per keypress. The previous window is kept in Lua state instead of an
-- address file, since Hyprland's own focus history is unreliable here.

local pippeek = require("lua/pippeek")

local M = {}

local STREMIO_CLASS = "com.stremio.Stremio"
local MPV_CLASS     = "mpv"

-- Survives config reloads, like pippeek's state.
local S = _G.__hl_mediafocus
if not S then
  S = { prev = nil }
  _G.__hl_mediafocus = S
end

local function focus(addr)
  if not addr then return false end
  local ok, w = pcall(hl.get_window, "address:" .. addr)
  if not (ok and w) then return false end
  hl.dispatch(hl.dsp.focus({ window = "address:" .. addr }))
  return true
end

local function focus_prev()
  local addr = S.prev
  S.prev = nil
  focus(addr)
end

function M.cycle()
  local ok, wins = pcall(hl.get_windows)
  if not (ok and wins) then return end

  local stremio, mpv, pip
  for _, w in ipairs(wins) do
    local cls = w.class or ""
    if not stremio and cls == STREMIO_CLASS then stremio = w.address end
    if not mpv and cls == MPV_CLASS then mpv = w.address end
  end
  -- The PiP slot excludes Stremio/mpv: is_pip() also matches those classes,
  -- so without this pip == stremio whenever Stremio is the only media window.
  for _, w in ipairs(wins) do
    if w.address ~= stremio and w.address ~= mpv and pippeek.is_pip(w) then
      pip = w.address
      break
    end
  end

  local aw = hl.get_active_window()
  local active = aw and aw.address

  if active and active == stremio then
    if mpv then focus(mpv) elseif pip then focus(pip) else focus_prev() end
  elseif active and active == pip then
    focus_prev()
  elseif active and active == mpv then
    if pip then focus(pip) else focus_prev() end
  else
    S.prev = active
    if stremio then focus(stremio)
    elseif mpv then focus(mpv)
    elseif pip then focus(pip)
    else S.prev = nil end
  end
end

return M
