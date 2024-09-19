return {
	"lukas-reineke/indent-blankline.nvim",
	main = "ibl",
	---@module "ibl"
	---@type ibl.config
	opts = {},
	config = function()
		require("ibl").setup({
			exclude = {
				filetypes = { "help", "terminal", "dashboard" },
			},
			scope = {
				enabled = true,
				show_start = true,
				show_end = true,
				highlight = { "Function", "Label" },
				priority = 500,
			},
		})
	end,
}
