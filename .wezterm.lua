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
config.color_scheme = "Catppuccin Mocha"
config.default_domain = "WSL:Arch"
config.font = wezterm.font_with_fallback({
	{ family = "JetBrainsMonoNL Nerd Font Mono", weight = "Bold" },
	{ family = "JetBrainsMonoNL Nerd Font Mono", weight = "Medium" },
	"FiraCode Nerd Font Mono",
	"Noto Sans JP",
	"Noto Sans KR",
	"Noto Sans",
})
config.font_size = 10.5
config.hide_tab_bar_if_only_one_tab = true
config.window_background_opacity = 0.9
config.win32_system_backdrop = "Mica"
config.window_close_confirmation = "NeverPrompt"

-- and finally, return the configuration to wezterm
return config
