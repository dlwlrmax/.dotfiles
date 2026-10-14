local vars = require("lua/variables")
local mainMod = vars.mainMod
local mainModS = vars.mainModS
local terminal = vars.terminal
local fileManager = vars.fileManager

-- Terminal
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))

-- Kill active
hl.bind(mainModS .. " + Q", hl.dsp.window.close())

-- Lock
hl.bind(mainModS .. " + M", hl.dsp.exec_cmd("hyprlock"))

-- Notifications: quickshell owns org.freedesktop.Notifications (swaync is not
-- installed/enabled, so its bind was removed).

-- File manager
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))

-- Float toggle + center (intentional duplicate bind: Hyprland dispatches both in sequence) 
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + V", hl.dsp.window.center())

-- App launcher (quickshell)
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("qs ipc call launcher toggle"))
-- Rofi fallback (temporary, drop later). Needs an explicit mode argument.
hl.bind(mainModS .. " + D", hl.dsp.exec_cmd("rofi -show drun"))

-- Power menu (quickshell)
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("qs ipc call power toggle"))

-- Cycle audio output device (quickshell)
hl.bind(mainMod .. " + CTRL + A", hl.dsp.exec_cmd("qs ipc call audio cycle"))

-- Screenshot
hl.bind(mainModS .. " + S", hl.dsp.exec_cmd('grim -g "$(slurp -d)" - | swappy -f -'))

-- Focus cycle (Stremio/mpv/PiP/prev). PIP hover-peek guard and the focus change
-- both run synchronously in this key event, so the peek poll can never see an
-- unguarded tick between them.
local pippeek = require("lua/pippeek")
local mediafocus = require("lua/mediafocus")
hl.bind(mainMod .. " + S", function()
  pippeek.block_until_leave()
  mediafocus.cycle()
end)

-- Fullscreen
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mainModS .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

-- Volume control (hardware media keys / rotary knob)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("XF86AudioMute",       hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))

-- Media playback (hardware media keys)
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"))
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"))

-- Focus movement: mainMod + h/j/l (k intentionally omitted)
local focus_dirs = { h = "left", l = "right", j = "down" }
for key, dir in pairs(focus_dirs) do
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = dir }))
  hl.bind(mainMod .. " + " .. key, hl.dsp.window.bring_to_top())
end

-- Previous workspace
hl.bind(mainMod .. " + q", hl.dsp.focus({ workspace = "previous" }))

-- Workspace next/prev on other monitor
hl.bind(mainModS .. " + n", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainModS .. " + p", hl.dsp.focus({ workspace = "m-1" }))

-- Window movement: mainModS + h/j/k/l
local move_dirs = { h = "left", l = "right", k = "up", j = "down" }
for key, dir in pairs(move_dirs) do
  hl.bind(mainModS .. " + " .. key, hl.dsp.window.move({ direction = dir }))
end

-- Switch workspaces with mainMod + [0-9]
for i = 1, 10 do
  local key = i % 10
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
end

-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
  local key = i % 10
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Mouse cursor movement with keyboard via wlrctl
local pointer_move = { h = "-10 0", l = "10 0", k = "0 -10", j = "0 10" }
for key, delta in pairs(pointer_move) do
  hl.bind(mainMod .. " + ALT + " .. key, hl.dsp.exec_cmd("wlrctl pointer move " .. delta), { repeating = true })
end

-- Mouse clicks
hl.bind(mainMod .. " + ALT + Return",   hl.dsp.exec_cmd("wlrctl pointer click left"))
hl.bind(mainMod .. " + ALT + BackSpace", hl.dsp.exec_cmd("wlrctl pointer click right"))

-- Mouse scroll (wheel axis)
local pointer_scroll = { p = "1", n = "-1" }
for key, dir in pairs(pointer_scroll) do
  hl.bind(mainMod .. " + ALT + " .. key, hl.dsp.exec_cmd("ydotool mousemove --wheel -x 0 -y " .. dir), { repeating = true })
end

-- Alt+Tab MRU switcher (quickshell alttab/AltTab.qml). First press opens the
-- switcher and enters the "alttab" submap; while Alt is held, Tab/Shift+Tab step
-- through windows; releasing Alt focuses the selection and resets the submap.
local function alttab_start(dir)
  return function()
    hl.dispatch(hl.dsp.global("quickshell:alttab" .. dir))
    hl.dispatch(hl.dsp.submap("alttab"))
  end
end
hl.bind("ALT + Tab", alttab_start("Next"))
hl.bind("ALT + SHIFT + Tab", alttab_start("Prev"))

hl.define_submap("alttab", function()
  hl.bind("ALT + Tab", hl.dsp.global("quickshell:alttabNext"), { repeating = true })
  hl.bind("ALT + SHIFT + Tab", hl.dsp.global("quickshell:alttabPrev"), { repeating = true })
  hl.bind("ALT + Escape", function()
    hl.dispatch(hl.dsp.global("quickshell:alttabCancel"))
    hl.dispatch(hl.dsp.submap("reset"))
  end)
end)
-- Alt release commits. Must live outside the submap: Alt was pressed in the
-- default submap, and an in-submap release bind never fires for it. Universal +
-- transparent + non_consuming so it matches from "alttab" and apps still see
-- the Alt release.
hl.bind("ALT + Alt_L", function()
  if hl.get_current_submap() ~= "alttab" then return end
  hl.dispatch(hl.dsp.global("quickshell:alttabCommit"))
  hl.dispatch(hl.dsp.submap("reset"))
end, { release = true, transparent = true, non_consuming = true, submap_universal = true })

-- Monitor cycle
hl.bind(mainMod .. " + Tab", hl.dsp.focus({ monitor = "+1" }))

-- Mouse binds for window drag/resize
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Input Method toggle
hl.bind("ALT + Z", hl.dsp.exec_cmd("fcitx5-remote -t"))

-- Clipboard via quickshell
hl.bind("CTRL + semicolon", hl.dsp.exec_cmd("qs ipc call clipboard toggle"))
