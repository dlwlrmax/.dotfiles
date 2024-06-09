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

config.use_ime = true
config.ime_preedit_rendering = "Builtin"

config.font = wezterm.font_with_fallback({
	{ family = "JetBrainsMono Nerd Font", weight = "Medium", scale = scale },
	{ family = "FiraCode Nerd Font", weight = "Medium", scale = scale },
	{ family = "Noto Sans JP", scale = scale },
	{ family = "Noto Sans KR", scale = scale },
	{ family = "Noto Sans", scale = scale },
})
config.font_size = 10
config.use_cap_height_to_scale_fallback_fonts = true
config.hide_tab_bar_if_only_one_tab = true
config.window_padding = {
	left = 8,
	right = 8,
	top = 8,
	bottom = 8,
}
config.line_height = 1.1
-- Other useful config options:
config.use_dead_keys = false
config.scrollback_lines = 3500
config.disable_default_key_bindings = true
if currentOs == "Windows" then
	config.disable_default_key_bindings = false
end
config.keys = {
	{
		key = "c",
		mods = "SHIFT|CTRL",
		action = wezterm.action.CopyTo("Clipboard"),
	},
	{
		key = "v",
		mods = "SHIFT|CTRL",
		action = wezterm.action.PasteFrom("Clipboard"),
	},
	{
		key = "r",
		mods = "SHIFT|CTRL",
		action = wezterm.action.ReloadConfiguration,
	},
  {
    key = "a",
    mods = "CTRL",
    action = wezterm.action.CopyMode 'MoveToStartOfLine'
  }
}
config.adjust_window_size_when_changing_font_size = false
--UI related config
config.window_background_opacity = 0.98

config.enable_wayland = false
if currentOs == "Windows" then
	config.window_background_opacity = 0
	config.win32_system_backdrop = "Mica"
	config.window_close_confirmation = "NeverPrompt"
	config.enable_wayland = false
end

config.initial_rows = 42
config.initial_cols = 192
config.warn_about_missing_glyphs = false

-- Keybindings
local act = wezterm.action

return config
