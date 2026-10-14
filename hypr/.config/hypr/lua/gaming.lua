-- ──────────────────────────────────────────────
-- Auto gaming profile
-- ──────────────────────────────────────────────
-- While the active window is a fullscreen game, turn off the GPU-heavy eye
-- candy (animations, blur, shadows) and tell quickshell to go quiet (no
-- popups, slower polls). Everything is restored when the game loses focus,
-- leaves fullscreen or closes. Event-driven: no polling.
--
-- Manual override (scripts/gamemode.sh):
--   hyprctl eval 'require("lua/gaming").force(true)'   -- on regardless
--   hyprctl eval 'require("lua/gaming").force(nil)'    -- back to auto

local M = {}

-- Settings switched off while gaming; their current values are captured
-- before switching, so the restore follows whatever variables.lua sets.
local KEYS = { "animations.enabled", "decoration.blur.enabled", "decoration.shadow.enabled" }

local S = { active = false, forced = nil, saved = nil }

local function is_game(w)
  if not w then return false end
  local cls = w.class or ""
  return cls:match("^steam_app_") ~= nil
    or cls == "gamescope"
    or w.content_type == "game"
end

local function nest(key, value, into)
  local t = into
  local parts = {}
  for part in key:gmatch("[^.]+") do parts[#parts + 1] = part end
  for i = 1, #parts - 1 do
    t[parts[i]] = t[parts[i]] or {}
    t = t[parts[i]]
  end
  t[parts[#parts]] = value
  return into
end

local function apply(on)
  if on == S.active then return end
  S.active = on
  local cfg = {}
  if on then
    S.saved = {}
    for _, k in ipairs(KEYS) do
      local ok, v = pcall(hl.get_config, k)
      if ok and v ~= nil then S.saved[k] = v else S.saved[k] = true end
      nest(k, false, cfg)
    end
  else
    for _, k in ipairs(KEYS) do
      local v = true
      if S.saved and S.saved[k] ~= nil then v = S.saved[k] end
      nest(k, v, cfg)
    end
    S.saved = nil
  end
  hl.config(cfg)
  hl.exec_cmd("qs ipc call gaming set " .. tostring(on))
end

local function evaluate()
  if S.forced ~= nil then return apply(S.forced) end
  local ok, w = pcall(hl.get_active_window)
  apply(ok and is_game(w) and (w.fullscreen or 0) ~= 0 or false)
end

function M.force(on)
  S.forced = on
  evaluate()
end

function M.is_active()
  return S.active
end

for _, ev in ipairs({ "window.active", "window.fullscreen", "window.close", "window.destroy" }) do
  pcall(hl.on, ev, evaluate)
end

-- A config reload re-applies the normal look; re-enter the profile if a game
-- is still up.
pcall(evaluate)

return M
