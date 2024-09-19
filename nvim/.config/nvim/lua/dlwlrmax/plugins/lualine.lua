local setup, lualine = pcall(require, "lualine")
local noice_setup, noice = pcall(require, "noice")

if not setup then
	return
end

lualine.setup({
	options = {
		theme = "catppuccin",
		component_separators = "|",
	},
	sections = {
		lualine_a = {
      { 'mode', upper = true },
			{
				-- noice.api.statusline.mode.get,
				-- cond = noice.api.statusline.mode.has,
			},
		},
		lualine_b = { "branch", "diff", "diagnostics" },
		lualine_c = { { "filename", file_status = false, path = 1 } },
		lualine_x = { "encoding", "fileformat", "filetype", "tabnine" },
		lualine_y = { "tabnine" },
		lualine_z = {
			{ "location", left_padding = 2 },
		},
	},
	inactive_sections = {
		lualine_a = { "filename" },
		lualine_b = {},
		lualine_c = {},
		lualine_x = {},
		lualine_y = {},
		lualine_z = { "location" },
	},
	tabline = {},
	extensions = {},
})
