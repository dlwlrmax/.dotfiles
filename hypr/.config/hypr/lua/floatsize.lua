-- ──────────────────────────────────────────────
-- Floating window placement (macOS / Windows style)
-- ──────────────────────────────────────────────
-- Runs synchronously in window.open: the payload already carries the rule-
-- applied size/position, so corrections land before the first frame (no
-- visible jump). Everything is one-shot; the window resizes freely after.
--
--   1. Remember: the last floating position + size of each app window
--      (class + initial title) is saved on close and restored on open,
--      clamped to the monitor's work area. Persisted across sessions.
--   2. Otherwise size it: a window that opens floating is only SHRUNK if
--      bigger than MAX (dialogs/popups keep their size). SUPER+V
--      (tiled -> float) also GROWS it to MIN.
--   3. Avoid overlap:
--      • an app's first window on the workspace (>= MIN size) uses smart
--        placement: if it overlaps another floating window, move to the spot
--        with the least overlap, preferring the one nearest where Hyprland put
--        it (center);
--      • small windows, and any window whose app already has a window there
--        (dialogs, "Tip of the day"...), only cascade off windows of the same
--        app (offset down-right by CASCADE_STEP), so they stay centered over
--        their parent.
--   4. Re-check after RECHECK_MS: Electron apps restore their own size after
--      mapping, which can undo the cap.
-- PIP, pinned and fullscreen windows are left alone.
--
-- A min_size/max_size rule would be a permanent clamp, and min_size also
-- inflated small dialogs (see windowrules.lua) — hence one-shot Lua.

local pippeek = require("lua/pippeek")

local M = {}

-- Fractions of the monitor's work area.
local MAX_W, MAX_H = 0.80, 0.85
local MIN_W, MIN_H = 0.45, 0.50
local CASCADE_STEP = 32 -- px offset per cascaded window
local CASCADE_TOL = 16  -- top-lefts closer than this count as "same spot"
local WRAP_PAD = 36     -- restart offset from the work area's top-left after wrapping
local RECHECK_MS = 600  -- second look for apps that resize themselves after mapping
local SMART_GRID = 32   -- candidate spacing (px) for smart placement
local SMART_PAD = 12    -- keep this far from the work area edges

local STATE_DIR = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/hypr"
local STATE_FILE = STATE_DIR .. "/floatgeom.tsv"

-- Shared across config reloads.
local S = _G.__hl_floatsize
if not S then
  S = { geom = nil }
  _G.__hl_floatsize = S
end

-- Steam toasts are placed by the "steam-toast" window rule (screen corner);
-- never remember/restore/cascade them, or geometry memory would re-center them.
local function is_toast(w)
  return w.class == "steam"
    and tostring(w.title or w.initial_title or ""):find("^notificationtoasts") ~= nil
end

local function skip(w)
  return not w or not w.floating or w.pinned
    or (w.fullscreen or 0) ~= 0
    or pippeek.is_pip(w)
    or is_toast(w)
end

local function get(addr)
  local ok, w = pcall(hl.get_window, "address:" .. addr)
  return ok and w or nil
end

-- Monitor area minus reserved space (bar).
local function work_area(mon)
  local r = type(mon.reserved) == "table" and mon.reserved or {}
  local l, t = r.left or 0, r.top or 0
  return {
    x = mon.x + l,
    y = mon.y + t,
    w = mon.width - l - (r.right or 0),
    h = mon.height - t - (r.bottom or 0),
  }
end

local function clamp(v, lo, hi)
  if hi < lo then return lo end
  return math.max(lo, math.min(v, hi))
end

local function sel(w) return "address:" .. w.address end

local function set_geom(w, x, y, width, height)
  if width ~= w.size.x or height ~= w.size.y then
    hl.dispatch(hl.dsp.window.resize({ x = width, y = height, window = sel(w) }))
  end
  if x ~= w.at.x or y ~= w.at.y then
    hl.dispatch(hl.dsp.window.move({ x = x, y = y, window = sel(w) }))
  end
end

-- ── remembered geometry ──────────────────────────────────────

local function key(w)
  local cls = w.class or ""
  if cls == "" then return nil end
  return cls .. "|" .. (w.initial_title or "")
end

local function load_geom()
  if S.geom then return S.geom end
  S.geom = {}
  local f = io.open(STATE_FILE, "r")
  if not f then return S.geom end
  for line in f:lines() do
    local k, mon, x, y, w, h = line:match("^(.-)\t(.-)\t(-?%d+)\t(-?%d+)\t(%d+)\t(%d+)$")
    if k then
      S.geom[k] = { mon = mon, x = tonumber(x), y = tonumber(y), w = tonumber(w), h = tonumber(h) }
    end
  end
  f:close()
  return S.geom
end

local function save_geom()
  local f = io.open(STATE_FILE, "w")
  if not f then
    os.execute("mkdir -p '" .. STATE_DIR .. "'")
    f = io.open(STATE_FILE, "w")
    if not f then return end
  end
  for k, g in pairs(S.geom or {}) do
    f:write(string.format("%s\t%s\t%d\t%d\t%d\t%d\n", k, g.mon, g.x, g.y, g.w, g.h))
  end
  f:close()
end

local has_sibling -- defined below (cascade section)

-- Store w's geometry relative to its monitor's work area. Only an app's main
-- window: dialogs open centered over their parent, not at a remembered spot.
local function remember(w)
  if skip(w) or not (w.monitor and w.at and w.size) then return false end
  if has_sibling(w) then return false end
  local k = key(w)
  if not k or k:find("[\t\n]") then return false end
  local a = work_area(w.monitor)
  load_geom()[k] = { mon = w.monitor.name, x = w.at.x - a.x, y = w.at.y - a.y, w = w.size.x, h = w.size.y }
  return true
end

-- Put w where it last was, clamped to the current work area. -> true if done.
local function restore(w)
  if has_sibling(w) then return false end
  local k = key(w)
  local g = k and load_geom()[k]
  if not g or not w.monitor or g.mon ~= w.monitor.name then return false end
  local a = work_area(w.monitor)
  local width = math.min(g.w, math.floor(a.w * MAX_W))
  local height = math.min(g.h, math.floor(a.h * MAX_H))
  set_geom(w,
    clamp(a.x + g.x, a.x, a.x + a.w - width),
    clamp(a.y + g.y, a.y, a.y + a.h - height),
    width, height)
  return true
end

-- ── sizing ───────────────────────────────────────────────────

-- Resize into range and re-center. grow = also enforce the minimum.
local function fit(w, grow)
  if not (w.monitor and w.size) then return false end
  local a = work_area(w.monitor)
  local cw, ch = w.size.x, w.size.y
  local nw = math.min(cw, math.floor(a.w * MAX_W))
  local nh = math.min(ch, math.floor(a.h * MAX_H))
  if grow then
    nw = math.max(nw, math.floor(a.w * MIN_W))
    nh = math.max(nh, math.floor(a.h * MIN_H))
  end
  if nw == cw and nh == ch then return false end
  hl.dispatch(hl.dsp.window.resize({ x = nw, y = nh, window = sel(w) }))
  hl.dispatch(hl.dsp.window.center({ window = sel(w) }))
  return true
end

local function is_large(w)
  local a = work_area(w.monitor)
  return w.size.x >= a.w * MIN_W and w.size.y >= a.h * MIN_H
end

-- ── cascade ──────────────────────────────────────────────────

-- Top-lefts w must avoid: other visible floating windows on its workspace;
-- for small windows (dialogs) only those of the same app.
local function occupied_corners(w)
  local ws = w.workspace and w.workspace.id
  local out = {}
  local ok, wins = pcall(hl.get_windows, { floating = true })
  if not (ok and wins and ws) then return out end
  local any_app = is_large(w)
  for _, o in ipairs(wins) do
    if o.address ~= w.address and o.at and not o.hidden
      and o.workspace and o.workspace.id == ws and not skip(o)
      and (any_app or o.class == w.class) then
      out[#out + 1] = o.at
    end
  end
  return out
end

local function taken(corners, x, y)
  for _, c in ipairs(corners) do
    if math.abs(c.x - x) < CASCADE_TOL and math.abs(c.y - y) < CASCADE_TOL then return true end
  end
  return false
end

local function cascade(w)
  if not (w.monitor and w.at and w.size) then return end
  local corners = occupied_corners(w)
  local x, y = w.at.x, w.at.y
  if not taken(corners, x, y) then return end
  local a = work_area(w.monitor)
  local right, bottom = a.x + a.w, a.y + a.h
  local wraps = 0
  for _ = 1, 64 do
    x, y = x + CASCADE_STEP, y + CASCADE_STEP
    if x + w.size.x > right or y + w.size.y > bottom then
      wraps = wraps + 1
      -- Each wrap starts one step further right so columns don't stack.
      x = a.x + WRAP_PAD + (wraps - 1) * CASCADE_STEP
      y = a.y + WRAP_PAD
      if x + w.size.x > right then return end
    end
    if not taken(corners, x, y) then
      hl.dispatch(hl.dsp.window.move({ x = x, y = y, window = sel(w) }))
      return
    end
  end
end

-- ── smart placement ──────────────────────────────────────────

-- Other visible floating windows on w's workspace, as boxes.
local function floating_boxes(w)
  local ws = w.workspace and w.workspace.id
  local out = {}
  local ok, wins = pcall(hl.get_windows, { floating = true })
  if not (ok and wins and ws) then return out end
  for _, o in ipairs(wins) do
    if o.address ~= w.address and o.at and o.size and not o.hidden
      and o.workspace and o.workspace.id == ws and not skip(o) then
      out[#out + 1] = { x = o.at.x, y = o.at.y, w = o.size.x, h = o.size.y }
    end
  end
  return out
end

local function overlap(boxes, x, y, width, height)
  local total = 0
  for _, b in ipairs(boxes) do
    local ox = math.min(x + width, b.x + b.w) - math.max(x, b.x)
    local oy = math.min(y + height, b.y + b.h) - math.max(y, b.y)
    if ox > 0 and oy > 0 then total = total + ox * oy end
  end
  return total
end

-- Move w to the least-overlapping spot in its work area (nearest its current
-- position on ties). No-op if it doesn't overlap anything where it is.
local function smart_place(w)
  if not (w.monitor and w.at and w.size) then return end
  local boxes = floating_boxes(w)
  local width, height = w.size.x, w.size.y
  local best = overlap(boxes, w.at.x, w.at.y, width, height)
  if best == 0 then return end
  local a = work_area(w.monitor)
  local x0, x1 = a.x + SMART_PAD, a.x + a.w - width - SMART_PAD
  local y0, y1 = a.y + SMART_PAD, a.y + a.h - height - SMART_PAD
  if x1 < x0 then x0, x1 = a.x, a.x end
  if y1 < y0 then y0, y1 = a.y, a.y end
  local bx, by, bdist = w.at.x, w.at.y, 0
  local function try(x, y)
    local o = overlap(boxes, x, y, width, height)
    local d = (x - w.at.x) ^ 2 + (y - w.at.y) ^ 2
    if o < best or (o == best and d < bdist) then best, bx, by, bdist = o, x, y, d end
  end
  for y = y0, y1, SMART_GRID do
    for x = x0, x1, SMART_GRID do try(x, y) end
    try(x1, y) -- flush against the right edge
  end
  for x = x0, x1, SMART_GRID do try(x, y1) end -- and the bottom edge
  try(x1, y1)
  if bx ~= w.at.x or by ~= w.at.y then
    hl.dispatch(hl.dsp.window.move({ x = bx, y = by, window = sel(w) }))
  end
end

-- Does w's app already have another window (tiled or floating) on w's workspace?
function has_sibling(w)
  local ws = w.workspace and w.workspace.id
  local ok, wins = pcall(hl.get_windows)
  if not (ok and wins and ws and w.class) then return false end
  for _, o in ipairs(wins) do
    if o.address ~= w.address and o.class == w.class
      and o.workspace and o.workspace.id == ws then
      return true
    end
  end
  return false
end

-- First app window: smart placement; dialogs/secondary windows: same-app cascade.
local function avoid_overlap(w)
  if not (w.monitor and w.size) then return end
  if is_large(w) and not has_sibling(w) then smart_place(w) else cascade(w) end
end

-- ── flow ─────────────────────────────────────────────────────

-- Second look: cap size again, keep the window inside the work area.
local function recheck(addr)
  local w = get(addr)
  if skip(w) or not (w.monitor and w.at and w.size) then return end
  local a = work_area(w.monitor)
  local width = math.min(w.size.x, math.floor(a.w * MAX_W))
  local height = math.min(w.size.y, math.floor(a.h * MAX_H))
  set_geom(w,
    clamp(w.at.x, a.x, a.x + a.w - width),
    clamp(w.at.y, a.y, a.y + a.h - height),
    width, height)
end

-- Steam toast: bottom-right of the work area, 10px margins. Static window-rule
-- `move` never fires for these, so position them from window.open instead;
-- re-run after RECHECK_MS in case the client resizes after mapping.
local TOAST_PAD = 10
local function place_toast(w)
  if not (w.monitor and w.size) then return end
  local a = work_area(w.monitor)
  hl.dispatch(hl.dsp.window.move({
    x = a.x + a.w - w.size.x - TOAST_PAD,
    y = a.y + a.h - w.size.y - TOAST_PAD,
    window = sel(w),
  }))
end

local function place(w, grow)
  if is_toast(w) then
    place_toast(w)
    pcall(hl.timer, function()
      local t = get(w.address)
      if t then place_toast(t) end
    end, { timeout = RECHECK_MS, type = "oneshot" })
    return
  end
  if skip(w) then return end
  local addr = w.address
  if not restore(w) then fit(w, grow) end
  w = get(addr)
  if w then avoid_overlap(w) end
  pcall(hl.timer, function() recheck(addr) end, { timeout = RECHECK_MS, type = "oneshot" })
end

-- SUPER+V: toggle float; a window that just became floating is placed like a
-- new one (remembered spot, else sized both ways + centered).
function M.toggle_float()
  hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
  local w = hl.get_active_window()
  if skip(w) then return end
  if not restore(w) and not fit(w, true) then hl.dispatch(hl.dsp.window.center()) end
  w = get(w.address)
  if w then avoid_overlap(w) end
end

pcall(hl.on, "window.open", function(w) place(w, false) end)
pcall(hl.on, "window.close", function(w)
  if remember(w) then save_geom() end
end)
-- Session end doesn't close windows one by one: snapshot the floating ones.
pcall(hl.on, "hyprland.shutdown", function()
  local ok, wins = pcall(hl.get_windows, { floating = true })
  local any = false
  for _, w in ipairs(ok and wins or {}) do
    if remember(w) then any = true end
  end
  if any then save_geom() end
end)

return M
