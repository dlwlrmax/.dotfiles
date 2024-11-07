return {
	{
		"neovim/nvim-lspconfig",
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
		"williamboman/mason-lspconfig.nvim",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			local capabilities = require("cmp_nvim_lsp").default_capabilities()
            capabilities.textDocument.completion.completionItem.snippetSupport = true
			require("mason-lspconfig").setup({
				ensure_installed = {
					"ts_ls",
					"intelephense",
					"typos_lsp",
					"volar",
					"emmet_language_server",
					"tailwindcss",
				},
				handlers = {
					function(server_name)
						require("lspconfig")[server_name].setup({
							capabilities = capabilities,
							-- on_attach = on_attach
						})
					end,
					["volar"] = function()
						require("lspconfig").volar.setup({
                            capabilities = capabilities,
							init_options = {
								vue = {
									hybridMode = false,
								},
								typescript = {
									tsdk = vim.fn.getcwd() .. "/node_modules/typescript/lib",
								},
							},
						})
					end,
					["ts_ls"] = function()
						local mason_packages = vim.fn.stdpath("data") .. "/mason/packages"
						local volar_path = mason_packages .. "/vue-language-server/node_modules/@vue/language-server"
						require("lspconfig").ts_ls.setup({
							init_options = {
								plugins = {
									{
										name = "@vue/typescript-plugin",
										location = volar_path,
										languages = { "vue" },
									},
								},
							},
						})
					end,
					["intelephense"] = function()
						require("lspconfig").intelephense.setup({
							settings = {
								intelephense = {
									maxSize = 1000000,
								},
							},
						})
					end,
					["typos_lsp"] = function()
						local lspconfig = require("lspconfig")
						lspconfig.typos_lsp.setup({
							init_options = {
								config = "~/.config/nvim/typos.toml",
							},
						})
					end,
				},
			})
		end,
	},
}
