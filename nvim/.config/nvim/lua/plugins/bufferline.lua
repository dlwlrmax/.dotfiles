return {
	"akinsho/bufferline.nvim",
	version = "*",
	dependencies = "nvim-tree/nvim-web-devicons",
	config = function()
		local bufferline = require("bufferline")
		bufferline.setup({
			highlights = require("catppuccin.groups.integrations.bufferline").get({
				styles = { "bold" },
				custom = {
					all = {
						fill = { bg = "#000000" },
					},
					mocha = {
						background = { fg = "#ffffff" },
					},
					latte = {
						background = { fg = "#000000" },
					},
				},
			}),
			options = {
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
}
