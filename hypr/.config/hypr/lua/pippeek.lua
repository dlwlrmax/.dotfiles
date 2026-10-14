-- ──────────────────────────────────────────────
-- Picture-in-Picture hover-to-peek
-- ──────────────────────────────────────────────
-- Rest the cursor on a PIP window and it slides to PEEK_X (right side of the
-- layout) so it stops covering whatever is behind it. Leave both the original
-- spot and the peeked spot and it slides back.
-- Skipped entirely while that window is fullscreen.
--
-- Applies to every window matching is_pip(): mpv, the stremio PIP, and browser
-- PIPs (same set as the PIP rules in lua/windowrules.lua). Each PIP is tracked
-- independently. Browser PIP titles follow the media title, so a pinned floating
-- browser window counts even when its title no longer says "picture".
--
-- Hyprland has no pointer-enter event, so this polls the cursor position.
-- Everything stays in the compositor: hl.get_cursor_pos() + hl.dsp.window.move().
-- Pressing SUPER + S (focus cycle) freezes the peek until the cursor leaves every
-- PIP, so cycling focus onto a PIP never shoves it aside.
--
-- No key is bound to this. Runtime control, if ever needed:
--   hyprctl eval 'require("lua/pippeek").toggle()'
--   hyprctl eval '_G.__hl_pippeek.peek_x = 1900'

local M = {}

local DEFAULT_PEEK_X = 1950 -- absolute screen x while peeked (live override: state.peek_x)
local MARGIN   = 20   -- hover slack around each region
local POLL_MS  = 100  -- poll period while any PIP exists
local IDLE_MS  = 1000 -- poll period with no PIP (window events wake it early)
local ENTER_MS = 150  -- dwell on a PIP before peeking
local LEAVE_MS = 300  -- dwell away before restoring
local TOL      = 2    -- px tolerance for "still where we put it"
local ARM_LEAVE_MS = 500 -- cursor-away dwell that releases a SUPER+S peek block
local OVERVIEW_MAX_S  = 120 -- safety: forget a hymission overview we never saw close
local OVERVIEW_ARM_MS = 250 -- ignore close events this soon after open (stale ones from the last close)

-- Which windows count as a PIP. Remove an entry to opt that app out.
local PIP_CLASSES = {
  ["mpv"] = true,
  ["stremio-enhanced"] = true,
  ["com.stremio.Stremio"] = true,
}
local BROWSER_CLASSES = {
  ["zen"] = true,
  ["zen-beta"] = true,
  ["firefox"] = true,
  ["chromium"] = true,
  ["Chromium"] = true,
  ["chromium-browser"] = true,
  ["google-chrome"] = true,
  ["Google-chrome"] = true,
}

local function is_pip(w)
  if not w or not w.floating then return false end
  local cls = w.class or ""
  if PIP_CLASSES[cls] then return true end
  -- Browser PIPs are pinned floats whose title follows the media title.
  if w.pinned and BROWSER_CLASSES[cls] then return true end
  return (w.title or ""):lower():match("picture.*picture") ~= nil
end

-- Config reloads re-run this chunk: keep one shared state table and one timer.
local S = _G.__hl_pippeek
if not S then
  S = { enabled = true, peek_x = DEFAULT_PEEK_X, wins = {}, arm_blocked = false, arm_away = 0, timer = nil, idle = false }
  _G.__hl_pippeek = S
end

-- Switch the poll between fast (PIP on screen) and idle rates.
local function set_idle(idle)
  if S.idle == idle or not S.timer then return end
  if pcall(S.timer.set_timeout, S.timer, idle and IDLE_MS or POLL_MS) then
    S.idle = idle
  end
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

local function move_win(addr, x, y)
  hl.dispatch(hl.dsp.window.move({ x = x, y = y, window = "address:" .. addr }))
end

-- Live top-left of a tracked window, or nil if it is gone/not queryable.
local function window_at(addr)
  local ok, w = pcall(hl.get_window, "address:" .. addr)
  if ok and w and w.at then return w.at.x, w.at.y end
  return nil
end

local function new_win(addr, b)
  return {
    addr = addr,
    state = "normal",   -- "normal" | "peeked"
    original = b,       -- { x, y, w, h } resting box
    target = nil,       -- { x, y, w, h } peeked box
    hover_ticks = 0,
    away_ticks = 0,
    settle = 0,         -- ticks to skip re-reading geometry after our own move
    warm = 3,           -- loose home capture while the window rule is still placing it
  }
end

local function peek(w, st)
  local mon = w.monitor
  if not mon then return end -- hidden/detached window: leave it alone
  local x = S.peek_x or DEFAULT_PEEK_X
  local y = math.max(mon.y, math.min(w.at.y, mon.y + mon.height - w.size.y))
  st.target = { x = x, y = y, w = w.size.x, h = w.size.y }
  st.state = "peeked"
  st.hover_ticks = 0
  if math.abs(w.at.x - x) > TOL or math.abs(w.at.y - y) > TOL then
    move_win(st.addr, x, y)
  end
end

local function restore(st)
  local orig = st.original
  st.state, st.target = "normal", nil
  st.hover_ticks, st.away_ticks = 0, 0
  if orig then move_win(st.addr, orig.x, orig.y) end
end

-- p (cursor position, may be nil) and mod (Super held) are read once per tick.
local function step(w, st, p, mod)
  if (w.fullscreen or 0) ~= 0 or (w.fullscreen_client or 0) ~= 0 then
    -- Fullscreen: leave it alone, but keep the resting box so exit returns home.
    st.state, st.target = "normal", nil
    st.hover_ticks, st.away_ticks = 0, 0
    return
  end

  local cur = box(w)

  -- First sight: the window rule may still be placing the window, so hold the
  -- corner loosely for a few ticks before freezing it.
  if (st.warm or 0) > 0 and st.state == "normal" then
    st.warm = st.warm - 1
    st.original = cur
  end

  if st.settle > 0 then
    st.settle = st.settle - 1
  elseif st.state == "peeked" and st.target
    and (math.abs(cur.x - st.target.x) > TOL or math.abs(cur.y - st.target.y) > TOL) then
    -- Moved while peeked by something other than us: send it home, stop peeking.
    restore(st)
    st.settle = 2
  end

  -- The resting box is sticky: captured on first sight and never re-adopted from a
  -- later move. A displaced PIP stays displaced until the peek cycle or SUPER+S
  -- brings it home, instead of the move silently redefining "home".
  if not st.original then st.original = cur end
  if not S.enabled then return end

  if mod or S.arm_blocked or S.overview then
    st.hover_ticks, st.away_ticks = 0, 0
    return
  end

  if not p then return end

  if st.state == "normal" then
    if in_box(p.x, p.y, st.original, MARGIN) then
      st.hover_ticks = st.hover_ticks + 1
    else
      st.hover_ticks = 0
    end
    if st.hover_ticks * POLL_MS >= ENTER_MS then
      peek(w, st)
      st.settle = 2
    end
  else
    local near_original = in_box(p.x, p.y, st.original, MARGIN)
    local near_target = st.target and in_box(p.x, p.y, st.target, MARGIN)
    if near_original or near_target then
      st.away_ticks = 0
    else
      st.away_ticks = st.away_ticks + 1
    end
    if st.away_ticks * POLL_MS >= LEAVE_MS then
      restore(st)
      st.settle = 2
    end
  end
end

local function tick()
  -- Every PIP is floating: let the compositor skip tiled windows.
  local ok, wins = pcall(hl.get_windows, { floating = true })
  if not (ok and wins) then return end

  local pips = {}
  for i = 1, #wins do
    if is_pip(wins[i]) then pips[#pips + 1] = wins[i] end
  end

  -- No PIP on screen: drop state, release the latch, slow the poll down.
  if #pips == 0 then
    if next(S.wins) ~= nil then S.wins = {} end
    S.arm_blocked = false
    set_idle(true)
    return
  end
  set_idle(false)

  -- Read pointer and modifier state once per tick instead of once per PIP.
  local p = hl.get_cursor_pos()
  local mod = super_held()

  local seen = {}
  for _, w in ipairs(pips) do
    seen[w.address] = true
    local st = S.wins[w.address]
    if not st then
      st = new_win(w.address, box(w))
      S.wins[w.address] = st
    end
    step(w, st, p, mod)
  end

  for addr in pairs(S.wins) do
    if not seen[addr] then S.wins[addr] = nil end
  end

  -- Hymission overview open: previews are drawn over the real windows, so the
  -- cursor "hovering" a PIP's real box means nothing. Hold the block until the
  -- overview closes (see M.overview_open).
  if S.overview then
    local alt_released = false
    if S.overview_kind == "switch" then
      local ok, down = pcall(hl.is_key_down, "Alt_L")
      alt_released = ok and not down
    end
    if alt_released or (S.overview_since and os.time() - S.overview_since > OVERVIEW_MAX_S) then
      -- Switcher committed on Alt release (or we lost track): keep the block
      -- until the cursor leaves, same as a seen close.
      S.overview = false
      S.arm_blocked, S.arm_away = true, 0
    else
      S.arm_away = 0
      return
    end
  end

  -- A SUPER+S focus cycle freezes peekage until the cursor has been away from
  -- every PIP for ARM_LEAVE_MS. The dwell is required: focusing a PIP warps the
  -- cursor onto it, so releasing on the first "not inside right now" tick let the
  -- warp land afterwards and trigger a fresh peek.
  if S.arm_blocked then
    if p then
      local still_here = false
      for _, st in pairs(S.wins) do
        if (st.original and in_box(p.x, p.y, st.original, MARGIN))
          or (st.target and in_box(p.x, p.y, st.target, MARGIN)) then
          still_here = true
          break
        end
      end
      if still_here then
        S.arm_away = 0
      else
        S.arm_away = (S.arm_away or 0) + 1
        if S.arm_away * POLL_MS >= ARM_LEAVE_MS then
          S.arm_blocked, S.arm_away = false, 0
        end
      end
    end
  end
end

-- Not bound to a key; callable at runtime via hyprctl eval.
function M.toggle()
  S.enabled = not S.enabled
  if not S.enabled then
    for _, st in pairs(S.wins) do
      if st.state == "peeked" then
        restore(st)
        st.settle = 2
      end
    end
  end
  pcall(hl.notification.create, {
    text = "PIP hover-peek: " .. (S.enabled and "ON" or "OFF"),
    timeout = 1500,
  })
  return S.enabled
end

M.is_pip = is_pip

function M.is_enabled()
  return S.enabled
end

-- Called by the SUPER+S focus bind: put every tracked PIP back on its resting box
-- if it is not there (peeked or dragged off), then hold it there until the cursor
-- has been away from every PIP. Freezing alone was not enough: if the hover-peek
-- had already fired, the window stayed parked away from home.
function M.block_until_leave()
  S.arm_blocked, S.arm_away = true, 0
  for _, st in pairs(S.wins) do
    if st.original then
      local x, y = window_at(st.addr)
      if st.state == "peeked" or x == nil
        or math.abs(x - st.original.x) > TOL
        or math.abs(y - st.original.y) > TOL then
        restore(st)
        st.settle = 2
      end
    end
  end
end

local function start_timer()
  if S.timer then return true end
  return pcall(function()
    S.timer = hl.timer(tick, { timeout = POLL_MS, type = "repeat" })
    S.idle = false
  end)
end

-- Called by the hymission overview binds (lua/hymission.lua) right before the
-- overview opens. Hymission draws previews over the real windows and, on exit,
-- warps the cursor onto the focused window, so both phases would look like a
-- hover to the poll. Put PIPs home and block peeking until the overview closes
-- (its exit refocuses -> window/workspace.active), then until the cursor has left
-- every PIP for ARM_LEAVE_MS, same as SUPER+S.
-- kind: "switch" for the Alt+Tab switcher (ends on Alt release), else "overview".
function M.overview_open(kind)
  M.block_until_leave()
  S.overview = true
  S.overview_kind = kind or "overview"
  S.overview_since = os.time()
  -- Close events right after open are leftovers from the previous close.
  S.overview_token = (S.overview_token or 0) + 1
  S.overview_armed = false
  local token = S.overview_token
  pcall(hl.timer, function()
    if S.overview_token == token then S.overview_armed = true end
  end, { timeout = OVERVIEW_ARM_MS, type = "oneshot" })
end

-- Explicit close (SUPER+CTRL+TAB). Also the end of every detected close:
-- the exit warp may land on a PIP, so keep the block until the cursor leaves.
function M.overview_close()
  if not S.overview then return end
  S.overview = false
  S.arm_blocked, S.arm_away = true, 0
end

local function overview_closed()
  if S.overview_armed then M.overview_close() end
end
-- Exit fires window.active and/or workspace.active (not always both); neither
-- fires on open or while hovering previews.
pcall(hl.on, "window.active", overview_closed)
pcall(hl.on, "workspace.active", overview_closed)

if not start_timer() then
  hl.on("hyprland.start", start_timer)
end

-- A window can become a PIP on open, pin, or title/class change: snap the poll
-- back to full rate so the idle period never delays a peek.
local function wake() set_idle(false) end
for _, ev in ipairs({ "window.open", "window.pin", "window.title", "window.class" }) do
  pcall(hl.on, ev, wake)
end

return M
