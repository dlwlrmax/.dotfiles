return {
	"akinsho/toggleterm.nvim",
	version = "*",
	config = function()
		require("toggleterm").setup({
			size = 20,
			open_mapping = [[<c-t>]],
			hide_numbers = true,
			shade_filetypes = {},
			shade_terminals = true,
			shading_factor = 2,
			start_in_insert = true,
			direction = "horizontal", -- 'vertical' | 'horizontal' | 'window' | 'float',
			persis_size = true,
			close_on_exit = false,
			float_opts = {
				border = "curved",
				windblend = 0,
				highlight = {
					border = "Normal",
					background = "Normal",
				},
			},
		})
	end,
}
