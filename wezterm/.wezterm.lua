function getOS()
	-- ask LuaJIT first
	if jit then
		return jit.os
	end

	-- Unix, Linux variants
	local fh, err = assert(io.popen("uname -o 2>/dev/null", "r"))
	if fh then
		osname = fh:read()
	end

	return osname or "Windows"
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
local scale = 1.05

config.font = wezterm.font_with_fallback({
	{ family = "JetBrainsMonoNL Nerd Font Mono", weight = "Medium", scale = scale },
	{ family = "FiraCode Nerd Font Mono", weight = "Medium", scale = scale },
	{ family = "Noto Sans JP", scale = scale },
	{ family = "Noto Sans KR", scale = scale },
	{ family = "Noto Sans", scale = scale },
})
config.font_size = 10
config.hide_tab_bar_if_only_one_tab = true
config.window_background_opacity = 0.5
if currentOs == "Windows" then
	config.win32_system_backdrop = "Mica"
	config.window_close_confirmation = "NeverPrompt"
end
-- and finally, return the configuration to wezterm
return config
