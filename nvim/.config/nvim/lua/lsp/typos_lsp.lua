return {
	setup = function()
		vim.lsp.config("typos_lsp", {
			init_options = {
				config = "~/.config/nvim/typos.toml",
			},
		})
	end,
}
