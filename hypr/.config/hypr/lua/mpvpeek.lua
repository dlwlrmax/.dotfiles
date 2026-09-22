-- ──────────────────────────────────────────────
-- mpv PIP hover-to-peek
-- ──────────────────────────────────────────────
-- Rest the cursor on the mpv PIP and it slides to PEEK_X (right side, hanging
-- past the monitor edge) so it stops covering whatever is behind it. Leave both
-- the original spot and the peeked spot and it slides back.
-- Skipped entirely while mpv is fullscreen.
--
-- Hyprland has no pointer-enter event, so this polls the cursor position.
-- Everything stays in the compositor: hl.get_cursor_pos() + hl.dsp.window.move().
-- Toggle with SUPER + SHIFT + V (bound in lua/keybinds.lua).

local M = {}

local CLASS    = "mpv"
local DEFAULT_PEEK_X = 1950 -- absolute screen x while peeked (live override: state.peek_x)
local MARGIN   = 20   -- hover slack around each region
local POLL_MS  = 100  -- poll period
local ENTER_MS = 150  -- dwell on the PIP before peeking
local LEAVE_MS = 300  -- dwell away before restoring
local TOL      = 2    -- px tolerance for "still where we put it"

-- Config reloads re-run this chunk: keep one shared state table and one timer.
local S = _G.__hl_mpvpeek
if not S then
  S = {
    enabled = true,
    state = "normal",   -- "normal" | "peeked"
    original = nil,     -- { x, y, w, h } resting box
    target = nil,       -- { x, y, w, h } peeked box
    hover_ticks = 0,
    away_ticks = 0,
    settle = 0,         -- ticks to skip re-reading geometry after our own move
    peek_x = DEFAULT_PEEK_X, -- live-tunable peek x (durable default above)
    timer = nil,
  }
  _G.__hl_mpvpeek = S
end

local function get_pip()
  local ok, w = pcall(hl.get_window, "class:" .. CLASS)
  return ok and w or nil
end

local function box(w)
  return { x = w.at.x, y = w.at.y, w = w.size.x, h = w.size.y }
end

local function in_box(px, py, b, margin)
  return px >= b.x - margin and px <= b.x + b.w + margin
    and py >= b.y - margin and py <= b.y + b.h + margin
end

local function super_held()
  -- mainMod: never peek/restore while the user is holding Super (window drags, binds).
  local ok, down = pcall(hl.is_key_down, "Super_L")
  if ok and down then return true end
  ok, down = pcall(hl.is_key_down, "Super_R")
  return ok and down or false
end

local function move_pip(x, y)
  hl.dispatch(hl.dsp.window.move({ x = x, y = y, window = "class:" .. CLASS }))
end

local function reset()
  S.state, S.target = "normal", nil
  S.hover_ticks, S.away_ticks = 0, 0
end

local function peek(w)
  local mon = w.monitor
  local x = S.peek_x or DEFAULT_PEEK_X
  local y = math.max(mon.y, math.min(w.at.y, mon.y + mon.height - w.size.y))
  S.target = { x = x, y = y, w = w.size.x, h = w.size.y }
  S.state = "peeked"
  S.hover_ticks = 0
  if math.abs(w.at.x - x) > TOL or math.abs(w.at.y - y) > TOL then
    move_pip(x, y)
  end
end

local function restore()
  local orig = S.original
  reset()
  if orig then move_pip(orig.x, orig.y) end
end

local function tick()
  local w = get_pip()
  if not w then
    S.original = nil
    if S.state == "peeked" then reset() end
    return
  end

  if (w.fullscreen or 0) ~= 0 or (w.fullscreen_client or 0) ~= 0 then
    -- Fullscreen: leave it alone. Forget the peek so geometry is re-adopted on exit.
    S.state, S.target, S.original = "normal", nil, nil
    S.hover_ticks, S.away_ticks = 0, 0
    return
  end

  local cur = box(w)

  if S.settle > 0 then
    S.settle = S.settle - 1
  elseif S.state == "normal" then
    -- Adopt outside moves (drag, window rule, monitor change) as the new resting box.
    if not S.original
      or math.abs(cur.x - S.original.x) > TOL
      or math.abs(cur.y - S.original.y) > TOL then
      S.original = cur
    end
  elseif S.target
    and (math.abs(cur.x - S.target.x) > TOL or math.abs(cur.y - S.target.y) > TOL) then
    -- Moved while peeked: treat it as the new resting box.
    S.original, S.state, S.target = cur, "normal", nil
  end

  if not S.original then S.original = cur end
  if not S.enabled then return end

  if super_held() then
    S.hover_ticks, S.away_ticks = 0, 0
    return
  end

  local p = hl.get_cursor_pos()
  if not p then return end

  if S.state == "normal" then
    if in_box(p.x, p.y, S.original, MARGIN) then
      S.hover_ticks = S.hover_ticks + 1
    else
      S.hover_ticks = 0
    end
    if S.hover_ticks * POLL_MS >= ENTER_MS then
      peek(w)
      S.settle = 2
    end
  else
    local near_original = in_box(p.x, p.y, S.original, MARGIN)
    local near_target = S.target and in_box(p.x, p.y, S.target, MARGIN)
    if near_original or near_target then
      S.away_ticks = 0
    else
      S.away_ticks = S.away_ticks + 1
    end
    if S.away_ticks * POLL_MS >= LEAVE_MS then
      restore()
      S.settle = 2
    end
  end
end

function M.toggle()
  S.enabled = not S.enabled
  if not S.enabled and S.state == "peeked" then
    restore()
    S.settle = 2
  end
  pcall(hl.notification.create, {
    text = "mpv hover-peek: " .. (S.enabled and "ON" or "OFF"),
    timeout = 1500,
  })
  return S.enabled
end

function M.is_enabled()
  return S.enabled
end

if not S.timer then
  local ok = pcall(function()
    S.timer = hl.timer(tick, { timeout = POLL_MS, type = "repeat" })
  end)
  if not ok then
    hl.on("hyprland.start", function()
      if not S.timer then
        pcall(function()
          S.timer = hl.timer(tick, { timeout = POLL_MS, type = "repeat" })
        end)
      end
    end)
  end
end

return M
