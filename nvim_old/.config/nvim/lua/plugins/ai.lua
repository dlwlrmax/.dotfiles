return {
	{
		"Exafunction/windsurf.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"saghen/blink.cmp",
		},
		config = function()
			require("codeium").setup({
				enable_cmp_source = false,
				virtual_text = {
					enabled = true,
					quiet = true,
					filetypes = {
						markdown = false,
						snacks_picker_input = false,
					},
					default_filetype_enabled = true,
					key_bindings = {
						accept = "<M-l>",
						accept_word = "<M-w>",
						accept_line = false,
						idle_delay = 100,
						next = "<M-]>",
						prev = "<M-[>",
						dismiss = "<C-]>",
					},
				},
			})
		end,
	},
}
