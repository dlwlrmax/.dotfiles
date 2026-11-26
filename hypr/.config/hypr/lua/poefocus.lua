-- ──────────────────────────────────────────────
-- PoE ↔ Awakened PoE Trade: overlay stays above the game
-- ──────────────────────────────────────────────
-- Path of Exile runs as a borderless monitor-sized window (windowrules.lua)
-- exactly so the Awakened PoE Trade overlay can draw over it. Clicking back
-- into the game raises the game window, which buries the overlay below it —
-- and the overlay cannot win that back on its own: no_initial_focus keeps it
-- unfocused at map, and while the game holds focus nothing re-raises it. (A
-- price check can briefly steal focus — gaming.lua treats that as part of
-- the game session — but once the game is re-focused the overlay stays
-- buried.)
--
-- So: while APT is running, whenever the game becomes the active window,
-- re-raise every APT window above it. alter_zorder touches the z-stack only —
-- the game keeps keyboard and mouse (a real focus switch would eat WASD
-- mid-map), the overlay keeps drawing on top, and its X11-grab hotkeys keep
-- firing through the pass-binds in keybinds.lua.
--
-- The mechanism runs only while an APT window exists, mirroring the pass-bind
-- gating in keybinds.lua. `attached` is flipped by the APT open/close
-- watchers; while it is false the window.active handler is an early-out and
-- the sweep chain has died (it only re-arms while attached), so with APT
-- closed nothing acts. Two signals drive it while attached:
--   • window.active — clicking into the game from anywhere;
--   • a 3 s self-rescheduling sweep — Hyprland emits no event for a plain
--     raise, and clicking around inside the already-active game re-buries the
--     overlay without window.active refiring (same no-event gap as the
--     geometry guard in windowrules.lua).

local vars = require("lua/variables")

local M = {}

local attached = false
local sweep_armed = false

local function game_is_active()
  local ok, w = pcall(hl.get_active_window)
  return ok and w ~= nil and vars.is_poe_game(w)
end

-- Any APT window left? (Overlay and its popups share the class.)
local function trade_exists()
  local ok, wins = pcall(hl.get_windows)
  if not (ok and wins) then return false end
  for _, w in ipairs(wins) do
    if w.class == vars.poeTradeClass then return true end
  end
  return false
end

-- Every Awakened PoE Trade window (overlay and its popups share the class) to
-- the top of the z-stack. Already-on-top windows are left unmoved visually:
-- the dispatcher reorders only, never focuses.
function M.raise_overlays()
  local ok, wins = pcall(hl.get_windows)
  if not (ok and wins) then return end
  for _, w in ipairs(wins) do
    if w.class == vars.poeTradeClass and not w.hidden then
      hl.dispatch(hl.dsp.window.alter_zorder({
        window = "address:" .. w.address,
        mode = "top",
      }))
    end
  end
end

function M.is_attached()
  return attached
end

-- 3 s one-shot chain: arms on attach, re-arms each tick while attached, and
-- dies on the first tick after detach — so it only ever runs while APT is up.
-- The raise is pcall'd so a window vanishing mid-dispatch cannot kill the
-- chain for the rest of the session.
local function sweep_tick()
  sweep_armed = false
  if not attached then return end
  if game_is_active() then pcall(M.raise_overlays) end
  sweep_armed = true
  pcall(hl.timer, sweep_tick, { timeout = 3000, type = "oneshot" })
end

local function arm_sweep()
  if sweep_armed then return end
  sweep_armed = true
  pcall(hl.timer, sweep_tick, { timeout = 3000, type = "oneshot" })
end

local function enable()
  if attached then return end
  attached = true
  arm_sweep()
end

local function disable()
  attached = false
  -- Any pending sweep tick finds attached=false and ends the chain there.
end

-- One permanent handler, gated on the attached flag: zero work with APT down,
-- and no subscription lifecycle to get wrong on repeated open/close cycles.
pcall(hl.on, "window.active", function()
  if attached and game_is_active() then pcall(M.raise_overlays) end
end)

-- APT lifecycle watchers (registered for the module's lifetime).
pcall(hl.on, "window.open", function(w)
  if w ~= nil and w.class == vars.poeTradeClass then enable() end
end)
for _, ev in ipairs({ "window.close", "window.destroy" }) do
  pcall(hl.on, ev, function(w)
    -- A popup closing must not detach while the overlay window remains.
    if w ~= nil and w.class == vars.poeTradeClass and not trade_exists() then
      disable()
    end
  end)
end

-- APT already up when this config loads (reload / first start).
if trade_exists() then enable() end

return M
