return {
	"zbirenbaum/copilot.lua",
	cmd = "Copilot",
	event = "InsertEnter",
	config = function()
		require("copilot").setup({
			suggestion = {
				enabled = true,
				auto_trigger = true,
				debounce = 150,
				keymap = {
					accept = "<M-l>",
					next = "<M-j>",
					prev = "<M-k>",
					dismiss = "<M-h>",
				},
			},
            filetypes = {
                ["grug-far"] = false,
                ["grug-far-history"] = false
            }
		})
	end,
}
