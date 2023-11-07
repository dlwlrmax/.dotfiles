function getOS()
	-- ask LuaJIT first
	if jit then
		return jit.os
	end

	-- Unix, Linux variants
	local fh, err = assert(io.popen("uname -o 2>/dev/null", "r"))
	if fh then
		os_name = fh:read()
	end

	return os_name or "Windows"
end

-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
	config = wezterm.config_builder()
end

-- This is where you actually apply your config choices

-- For example, changing the color scheme:
config.color_scheme = "Catppuccin Macchiato"

local currentOs = getOS()
if currentOs == "Windows" then
	config.default_domain = "WSL:Arch"
end

-- Font scale factor
local scale = 1
if currentOs == "Windows" then
	scale = 1.05
end

config.font = wezterm.font_with_fallback({
	{ family = "JetBrainsMonoNL Nerd Font Mono", weight = "Medium", scale = scale },
	{ family = "FiraCode Nerd Font Mono", weight = "Medium", scale = scale },
	{ family = "Noto Sans JP", scale = scale },
	{ family = "Noto Sans KR", scale = scale },
	{ family = "Noto Sans", scale = scale },
})
config.font_size = 10
config.hide_tab_bar_if_only_one_tab = true
config.window_padding = {
	left = 8,
	right = 8,
	top = 8,
	bottom = 8,
}
config.line_height = 1.1
-- Other useful config options:
if currentOs == "Windows" then
	config.disable_default_key_bindings = true
end
config.use_dead_keys = false
config.scrollback_lines = 3500
config.adjust_window_size_when_changing_font_size = false
--UI related config
config.window_background_opacity = 0.5
if currentOs == "Windows" then
	config.window_background_opacity = 0
	config.win32_system_backdrop = "Mica"
	config.window_close_confirmation = "NeverPrompt"
end

-- Keybindings
local act = wezterm.action
local keys = {
	{ key = "R", mods = "SHIFT|CTRL", action = act.ReloadConfiguration },
}

-- and finally, return the configuration to wezterm
return config
