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
local POLL_MS  = 100  -- poll period
local ENTER_MS = 150  -- dwell on a PIP before peeking
local LEAVE_MS = 300  -- dwell away before restoring
local TOL      = 2    -- px tolerance for "still where we put it"

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
  if not w.floating then return false end
  local cls = w.class or ""
  if PIP_CLASSES[cls] then return true end
  -- Browser PIPs are pinned floats whose title follows the media title.
  if w.pinned and BROWSER_CLASSES[cls] then return true end
  return (w.title or ""):lower():match("picture.*picture") ~= nil
end

-- Config reloads re-run this chunk: keep one shared state table and one timer.
local S = _G.__hl_pippeek
if not S then
  S = { enabled = true, peek_x = DEFAULT_PEEK_X, wins = {}, arm_blocked = false, timer = nil }
  _G.__hl_pippeek = S
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

local function new_win(addr, b)
  return {
    addr = addr,
    state = "normal",   -- "normal" | "peeked"
    original = b,       -- { x, y, w, h } resting box
    target = nil,       -- { x, y, w, h } peeked box
    hover_ticks = 0,
    away_ticks = 0,
    settle = 0,         -- ticks to skip re-reading geometry after our own move
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
    -- Fullscreen: leave it alone. Forget the peek so geometry is re-adopted on exit.
    st.state, st.target, st.original = "normal", nil, nil
    st.hover_ticks, st.away_ticks = 0, 0
    return
  end

  local cur = box(w)

  if st.settle > 0 then
    st.settle = st.settle - 1
  elseif st.state == "normal" then
    -- Adopt outside moves (drag, window rule, monitor change) as the new resting box.
    if not st.original
      or math.abs(cur.x - st.original.x) > TOL
      or math.abs(cur.y - st.original.y) > TOL then
      st.original = cur
    end
  elseif st.target
    and (math.abs(cur.x - st.target.x) > TOL or math.abs(cur.y - st.target.y) > TOL) then
    -- Moved while peeked: treat it as the new resting box.
    st.original, st.state, st.target = cur, "normal", nil
  end

  if not st.original then st.original = cur end
  if not S.enabled then return end

  if mod or S.arm_blocked then
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
  local ok, wins = pcall(hl.get_windows)
  if not (ok and wins) then return end
  if #wins == 0 and next(S.wins) == nil then return end -- idle: nothing to poll for

  -- Read pointer and modifier state once per tick instead of once per PIP.
  local p = hl.get_cursor_pos()
  local mod = super_held()

  local seen = {}
  local any_pip = false
  for i = 1, #wins do
    local w = wins[i]
    if is_pip(w) then
      any_pip = true
      seen[w.address] = true
      local st = S.wins[w.address]
      if not st then
        st = new_win(w.address, box(w))
        S.wins[w.address] = st
      end
      step(w, st, p, mod)
    end
  end

  for addr in pairs(S.wins) do
    if not seen[addr] then S.wins[addr] = nil end
  end

  -- No PIP on screen: nothing can hold the latch.
  if not any_pip then
    S.arm_blocked = false
    return
  end

  -- A SUPER+S focus cycle freezes peekage until the cursor leaves every PIP.
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
      if not still_here then S.arm_blocked = false end
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

function M.is_enabled()
  return S.enabled
end

-- Called by the SUPER+S focus bind: no peek until the cursor leaves every PIP.
function M.block_until_leave()
  S.arm_blocked = true
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
