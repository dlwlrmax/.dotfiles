return {
	"williamboman/mason-lspconfig.nvim",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local capabilities = require("cmp_nvim_lsp").default_capabilities()

		require("mason-lspconfig").setup({
			ensure_installed = {
            },
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
		})
	end,
}
