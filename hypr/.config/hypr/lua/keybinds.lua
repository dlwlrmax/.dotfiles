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

-- Notifications
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("swaync-client -t -sw"))

-- File manager
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))

-- Float toggle + center
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + V", hl.dsp.window.center())

-- App launcher (quickshell)
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("qs ipc call launcher toggle"))
-- Rofi fallback (temporary, drop later)
hl.bind(mainModS .. " + D", hl.dsp.exec_cmd("rofi -show"))

-- Power menu (quickshell)
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("touch /tmp/quickshell-power-toggle"))

-- Screenshot
hl.bind(mainModS .. " + S", hl.dsp.exec_cmd('grim -g "$(slurp -d)" - | satty -f - --copy-command wl-copy'))

-- Fullscreen
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))

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

-- Alt+Tab cycle
hl.bind("ALT + Tab", hl.dsp.window.cycle_next())
hl.bind("ALT + Tab", hl.dsp.window.bring_to_top())

-- Mouse binds for window drag/resize
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Input Method toggle
hl.bind("ALT + Z", hl.dsp.exec_cmd("fcitx5-remote -t"))

-- Clipboard via rofi
hl.bind("CTRL + semicolon", hl.dsp.exec_cmd("rofi -modi clipboard:$HOME/.dotfiles/hypr/.config/hypr/scripts/cliphist-rofi-img -show clipboard -show-icons"))
