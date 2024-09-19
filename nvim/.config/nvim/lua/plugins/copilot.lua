return {
	"zbirenbaum/copilot.lua",
	cmd = "Copilot",
	event = "InsertEnter",
	config = function()
		require("copilot").setup({
			suggestion = {
				enabled = true,
				auto_trigger = true,
				debounce = 50,
				keymap = {
					accept = "<M-l>",
					next = "<M-j>",
					prev = "<M-k>",
					dismiss = "<M-h>",
				},
			},
		})
	end,
}
