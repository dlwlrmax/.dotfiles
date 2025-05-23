return {
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"saghen/blink.cmp",
		},
	},
	{
		"dmmulroy/ts-error-translator.nvim",
		config = function()
			require("ts-error-translator").setup({
				auto_override_publish_diagnostics = true,
			})
		end,
	}
}
