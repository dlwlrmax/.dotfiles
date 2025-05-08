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
	},
	{
		"stevearc/conform.nvim",
		event = { "BufWritePre" },
		cmd = { "ConformInfo" },
		keys = {
			{
				"<leader>nf",
				function()
					require("conform").format({ async = true })
				end,
				mode = "",
				desc = "Format Buffer",
			},
		},
		opts = {
			formatters_by_ft = {
				lua = { "stylua" },
				javascript = { "prettierd", "prettier", stop_after_first = true },
				vue = { "prettierd", "prettier", stop_after_first = true },
				php = { "pint", "php_cs_fixer", stop_after_first = true },
				markdown = { "prettierd", "prettier", stop_after_first = true },
				blade = { "blade-formatter" },
			},
			default_format_opts = {
				lsp_format = "fallback",
			},
		},
	},
	{
		"mfussenegger/nvim-lint",
		config = function()
			require("lint").linters_by_ft = {
				lua = { "luacheck" },
				javascript = { "eslint_d" },
				typescript = { "eslint_d" },
				vue = { "eslint_d" },
				php = { "phpstan" },
			}
			vim.api.nvim_create_autocmd({ "BufWritePost" }, {
				callback = function()
					require("lint").try_lint()
				end,
			})
		end,
	},
}
