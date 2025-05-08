local vim = vim or require("vim")
return {
	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		dependencies = {
			"mason-org/mason.nvim",
		},
		opts = {
			ensure_installed = {
				"stylua",
				"phpstan",
				"blade-formatter",
				"intelephense",
				"prettierd",
				"prettier",
				"eslint_d",
				"pint",
			},
			auto_update = true,
		},
	},
	{
		"williamboman/mason.nvim",
		config = function()
			local mason = require("mason")
			mason.setup({})
		end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = {
			"saghen/blink.cmp",
		},
		event = { "BufReadPre", "BufNewFile" },
		config = function()

            require("lsp.intelephense").setup()
            require('lsp.tailwindcss').setup()
            require("lsp.typos_lsp").setup()
            require("lsp.volar").setup()
			require("lsp.vtsls").setup()
			require("mason-lspconfig").setup({
				automatic_enable = true,
				ensure_installed = {
					"intelephense",
					"typos_lsp",
					"volar",
					"emmet_language_server",
					"tailwindcss",
					"vtsls",
				},
			})
		end,
	},
}
