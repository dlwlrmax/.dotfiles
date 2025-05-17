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
				"tailwindcss",
				"prettierd",
				"typos_lsp",
				"prettier",
				"vtsls",
				"eslint_d",
				"intelephense",
				"volar",
				"emmet_language_server",
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
            "williamboman/mason.nvim",
            "neovim/nvim-lspconfig",
		},
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			require("lsp.intelephense").setup()
			require("lsp.tailwindcss").setup()
			require("lsp.typos_lsp").setup()
			require("lsp.volar").setup()
			require("lsp.vtsls").setup()
			require("mason-lspconfig").setup({
				automatic_enable = true,
			})
		end,
	},
}
