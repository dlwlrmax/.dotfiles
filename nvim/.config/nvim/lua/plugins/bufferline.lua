return {
	{
		"akinsho/bufferline.nvim",
		version = "*",
		dependencies = "nvim-tree/nvim-web-devicons",
		config = function()
			local bufferline = require("bufferline")
			bufferline.setup({
				highlights = require("catppuccin.groups.integrations.bufferline").get({
					styles = { "bold" },
				}),
				options = {
					indicator = {
						style = "underline",
					},
					separator_style = "slop",
					diagnostics = "nvim_lsp",
					diagnostics_indicator = function(count, level)
						local icon = level:match("error") and " " or " "
						return "(" .. icon .. count .. ")"
					end,
					offsets = {
						{
							filetype = "NeoTree",
							text = function()
								return vim.fn.getcwd()
							end,
							highlight = "Directory",
						},
					},
				},
			})
		end,
	},
	{
		"famiu/bufdelete.nvim",
	},
}
