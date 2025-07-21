return {
	setup = function()
		vim.lsp.config("intelephense", {
			init_options = {
				config = "~/.config/nvim/intelephense.toml",
			},
		})
	end,
}
