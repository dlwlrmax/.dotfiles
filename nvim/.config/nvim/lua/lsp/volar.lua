return {
	setup = function()
		vim.lsp.config("volar", {
			init_options = {
				vue = {
					hybridMode = true,
				},
			},
			vtsls = {},
		})
	end,
}
