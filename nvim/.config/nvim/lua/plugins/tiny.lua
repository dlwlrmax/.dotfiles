return {
	{
		"rachartier/tiny-inline-diagnostic.nvim",
		event = "VeryLazy", -- Or `LspAttach`
		priority = 1000, -- needs to be loaded in first
		config = function()
			require("tiny-inline-diagnostic").setup({
				options = {
					show_source = true,
					multilines = {
						-- Enable multiline diagnostic messages
						enabled = true,

						-- Always show messages on all lines for multiline diagnostics
						always_show = false,
					},
					throttle = 200,
				},
			})
			vim.diagnostic.config({ virtual_text = false })
		end,
	},
	{
		"rachartier/tiny-glimmer.nvim",
		event = "VeryLazy",
		priority = 10, -- Needs to be a really low priority, to catch others plugins keybindings.
		opts = {
			overwrite = {
				auto_map = false,
			},
		},
	},
}
