return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	---@class wk.Opts
	opts = {
		preset = "helix",
	},
	keys = {
		{
			"<leader>?",
			function()
				require("which-key").show({ global = false })
			end,
			desc = "Buffer Local Keymaps (which-key)",
		},
	},
	config = function()
		local wk = require("which-key")
		wk.add({
            { "<leader>d", group = "DiffView" },
            { "<leader>g", group = "Git" },
            { "<leader>s", group = "LSP Saga/Move Split" },
            { "<leader>c", group = "LSP Saga/Code Action" },
		})
	end,
}
