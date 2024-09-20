return {
	"williamboman/mason-lspconfig.nvim",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local capabilities = require("cmp_nvim_lsp").default_capabilities()

		local mason_registry = require("mason-registry")
		local vue_language_server_path = mason_registry.get_package("vue-language-server"):get_install_path()
			.. "/node_modules/@vue/language-server"
		require("mason-lspconfig").setup({
			ensure_installed = {},
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
			["ts_ls"] = function()
				local lspconfig = require("lspconfig")
				lspconfig.ts_ls.setup({
					init_options = {
						plugins = {
							{
								name = "@vue/typescript-plugin",
								location = vue_language_server_path,
								languages = { "vue" },
							},
						},
					},
					filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" },
				})
			end,
		})
	end,
}
