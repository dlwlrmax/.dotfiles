return {
	setup = function()
		vim.lsp.config("vue_ls", {
			init_options = {
				vue = {
					hybridMode = true,
				},
			},
			vtsls = {},
		})
	end,
}
