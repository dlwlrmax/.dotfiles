local mainMod = "SUPER"
local mainModS = mainMod .. " + SHIFT"
local terminal = "ghostty"
local fileManager = "Thunar"

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

-- Rofi app launcher
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("rofi -show"))

-- Power menu (quickshell)
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("touch /tmp/quickshell-power-toggle"))

-- Screenshot
hl.bind(mainModS .. " + S", hl.dsp.exec_cmd('grim -g "$(slurp -d)" - | satty -f - --copy-command wl-copy'))

-- Fullscreen
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))

-- Focus movement
hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + h", hl.dsp.window.bring_to_top())
hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + l", hl.dsp.window.bring_to_top())
hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + j", hl.dsp.window.bring_to_top())

-- Previous workspace
hl.bind(mainMod .. " + q", hl.dsp.focus({ workspace = "previous" }))

-- Workspace next/prev on other monitor
hl.bind(mainModS .. " + n", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainModS .. " + p", hl.dsp.focus({ workspace = "m-1" }))

-- Window movement
hl.bind(mainModS .. " + l", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainModS .. " + h", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainModS .. " + k", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainModS .. " + j", hl.dsp.window.move({ direction = "down" }))

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
