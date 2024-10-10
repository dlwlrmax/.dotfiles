return {
	{ "AndreM222/copilot-lualine" },
	{
		"zbirenbaum/copilot.lua",
		cmd = "Copilot",
		event = "InsertEnter",
		config = function()
			require("copilot").setup({
				suggestion = {
					enabled = true,
					auto_trigger = true,
					hide_during_completion = false,
					debounce = 150,
					keymap = {
						accept = "<M-l>",
						accept_word = "<M-w>",
						next = "<M-j>",
						prev = "<M-k>",
						dismiss = "<M-h>",
					},
				},
				panel = {
					enabled = true,
					auto_refresh = false,
					keymap = {
						jump_prev = "[[",
						jump_next = "]]",
						accept = "<CR>",
						refresh = "gr",
						open = "<M-CR>",
					},
					layout = {
						position = "bottom", -- | top | left | right
						ratio = 0.4,
					},
				},
				filetypes = {
					["grug-far"] = false,
					["grug-far-history"] = false,
					["grug-far-help"] = false,
				},
				copilot_node_command = "node", -- Node.js version must be > 18.x
			})
		end,
	},
}
