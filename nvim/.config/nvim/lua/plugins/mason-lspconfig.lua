return {
	"williamboman/mason-lspconfig.nvim",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local capabilities = require("cmp_nvim_lsp").default_capabilities()

		require("mason-lspconfig").setup({
			ensure_installed = { "ts_ls", "intelephense", "typos_lsp", "volar" },
		})
		require("mason-lspconfig").setup_handlers({
			function(server_name)
				if server_name == "tsserver" then
					server_name = "ts_ls"
				end
				require("lspconfig")[server_name].setup({
					capabilities = capabilities,
					-- on_attach = on_attach
				})
			end,
			["intelephense"] = function()
				local lspconfig = require("lspconfig")
				lspconfig.intelephense.setup({
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
			["volar"] = function()
				require("lspconfig").volar.setup({
					-- NOTE: Uncomment to enable volar in file types other than vue.
					-- (Similar to Takeover Mode)

					-- filetypes = { "vue", "javascript", "typescript", "javascriptreact", "typescriptreact", "json" },

					-- NOTE: Uncomment to restrict Volar to only Vue/Nuxt projects. This will enable Volar to work alongside other language servers (tsserver).

					-- root_dir = require("lspconfig").util.root_pattern(
					--   "vue.config.js",
					--   "vue.config.ts",
					--   "nuxt.config.js",
					--   "nuxt.config.ts"
					-- ),
					init_options = {
						vue = {
							hybridMode = false,
						},
						-- NOTE: This might not be needed. Uncomment if you encounter issues.

						-- typescript = {
						--   tsdk = vim.fn.getcwd() .. "/node_modules/typescript/lib",
						-- },
					},
					settings = {
						typescript = {
							inlayHints = {
								enumMemberValues = {
									enabled = true,
								},
								functionLikeReturnTypes = {
									enabled = true,
								},
								propertyDeclarationTypes = {
									enabled = true,
								},
								parameterTypes = {
									enabled = true,
									suppressWhenArgumentMatchesName = true,
								},
								variableTypes = {
									enabled = true,
								},
							},
						},
					},
				})
			end,

			["ts_ls"] = function()
				local mason_packages = vim.fn.stdpath("data") .. "/mason/packages"
				local volar_path = mason_packages .. "/vue-language-server/node_modules/@vue/language-server"

				require("lspconfig").ts_ls.setup({
					-- NOTE: To enable hybridMode, change HybrideMode to true above and uncomment the following filetypes block.
					-- WARN: THIS MAY CAUSE HIGHLIGHTING ISSUES WITHIN THE TEMPLATE SCOPE WHEN TSSERVER ATTACHES TO VUE FILES

					-- filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" },
					init_options = {
						plugins = {
							{
								name = "@vue/typescript-plugin",
								location = volar_path,
								languages = { "vue" },
							},
						},
					},
					settings = {
						typescript = {
							inlayHints = {
								includeInlayParameterNameHints = "all",
								includeInlayParameterNameHintsWhenArgumentMatchesName = true,
								includeInlayFunctionParameterTypeHints = true,
								includeInlayVariableTypeHints = true,
								includeInlayVariableTypeHintsWhenTypeMatchesName = true,
								includeInlayPropertyDeclarationTypeHints = true,
								includeInlayFunctionLikeReturnTypeHints = true,
								includeInlayEnumMemberValueHints = true,
							},
						},
					},
				})
			end,
		})
	end,
}
