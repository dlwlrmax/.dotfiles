return {
	{
		"neovim/nvim-lspconfig",
	},
	{
		"j-hui/fidget.nvim",
		opts = {},
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
			local opts = { noremap = true, silent = true }
			vim.keymap.set({ "n", "i" }, "gI", function()
				vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
			end, opts)

			require("mason-lspconfig").setup({
				ensure_installed = {
					"intelephense",
					"typos_lsp",
					"volar",
					"emmet_language_server",
					"tailwindcss",
					"vtsls",
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
							-- capabilities = {
							-- 	textDocument = {
							-- 		completion = {
							-- 			completionItem = {
							-- 				snippetSupport = true,
							-- 			},
							-- 		},
							-- 	},
							-- },
							init_options = {
								vue = {
									hybridMode = true,
								},
							},
							vtsls = {},
						})
					end,
					["vtsls"] = function()
						require("lspconfig").vtsls.setup({
							filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" },
							settings = {
								vtsls = { tsserver = { globalPlugins = {} } },
							},
							before_init = function(params, config)
								local result = vim.system(
									{ "npm", "query", "#vue" },
									{ cwd = params.workspaceFolders[1].name, text = true }
								):wait()
								if result.stdout ~= "[]" then
									local vuePluginConfig = {
										name = "@vue/typescript-plugin",
										location = require("mason-registry")
											.get_package("vue-language-server")
											:get_install_path() .. "/node_modules/@vue/language-server",
										languages = { "vue" },
										configNamespace = "typescript",
										enableForWorkspaceTypeScriptVersions = true,
									}
									table.insert(config.settings.vtsls.tsserver.globalPlugins, vuePluginConfig)
								end
							end,
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
					["tailwindcss"] = function()
						local lspconfig = require("lspconfig")
						lspconfig.tailwindcss.setup({
							root_dir = require("lspconfig").util.root_pattern(
								"tailwind.config.js",
								"tailwind.config.ts",
								"postcss.config.js",
								"postcss.config.ts",
								"windi.config.ts"
							),
						})
					end,
				},
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
				-- Conform will run multiple formatters sequentially
				python = { "isort", "black" },
				-- You can customize some of the format options for the filetype (:help conform.format)
				rust = { "rustfmt", lsp_format = "fallback" },
				-- Conform will run the first available formatter
				javascript = { "prettierd", "prettier", stop_after_first = true },
				vue = { "prettierd", "prettier", stop_after_first = true },
				php = { "php_cs_fixer", "easy_coding_standard", stop_after_first = true },
			},
			default_format_opts = {
				lsp_format = "fallback",
			},
		},
	},
	{
		"mfussenegger/nvim-lint",
		config = function()
			require("lint").linters_by_fr = {
				lua = { "luacheck" },
				php = { "intelephense", "phpcs" },
			}
		end,
	},
}
