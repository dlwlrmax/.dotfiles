return {
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"saghen/blink.cmp",
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
		"dmmulroy/ts-error-translator.nvim",
		config = function()
			require("ts-error-translator").setup({
				auto_override_publish_diagnostics = true,
			})
		end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = {
			"saghen/blink.cmp",
		},
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			vim.keymap.set({ "n" }, "gI", function()
				vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
			end, { noremap = true, silent = true, desc = "Toggle inlay hints" })

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
						local lspconfig = require("lspconfig")
						local capabilities = require("blink.cmp").get_lsp_capabilities()
						lspconfig[server_name].setup({
							capabilities = capabilities,
							-- on_attach = on_attach
						})
					end,
					["volar"] = function()
						require("lspconfig").volar.setup({
							capabilities = {
								textDocument = {
									completion = {
										completionItem = {
											snippetSupport = true,
										},
									},
								},
							},
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
				javascript = { "prettierd", "prettier", stop_after_first = true },
				vue = { "prettierd", "prettier", stop_after_first = true },
				php = { "php_cs_fixer", "easy_coding_standard", stop_after_first = true },
				markdown = { "prettierd", "prettier", stop_after_first = true },
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
	{
		"nvimdev/lspsaga.nvim",
		dependencies = {
			"nvim-treesitter/nvim-treesitter", -- optional
			"nvim-tree/nvim-web-devicons", -- optional
		},
		after = "nvim-lspconfig",
		config = function()
			require("lspsaga").setup({
				symbol_in_winbar = {
					enable = true,
					hide_keyword = true,
					show_file = true,
					folder_level = 2,
					color_mode = true,
					delay = 1000,
				},
				code_action = {
					num_shortcut = true,
					show_server_name = true,
					extend_gitsigns = true,
					keys = {
						quit = "q",
						exec = "<CR>",
					},
				},
				definition = {
					keys = {
						quit = "q",
						edit = "<CR>",
						vsplit = "<C-v>",
						split = "<C-x>",
						tabe = "<C-t>",
					},
				},
				lightbulb = {
					enable = true,
					enable_in_insert = false,
					sign = true,
					sign_priority = 140,
					debounce = 300,
					virtual_text = false,
				},
				ui = {
					title = true,
					border = "rounded",
					winblend = 0,
					expand = "",
					collapse = "",
					code_action = "",
					incoming = " ",
					outgoing = " ",
					hover = " ",
					kind = require("catppuccin.groups.integrations.lsp_saga").custom_kind(),
				},
				implement = {
					enable = true,
					sign = true,
					virtual_text = true,
					priority = 100,
				},
			})
		end,
	},
}
