local setup, toggleterm = pcall(require, "toggleterm")
if not setup then
	return
end

toggleterm.setup({
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
		hightlight = {
			border = "Normal",
			background = "Normal",
		},
	},
})
local Terminal = require("toggleterm.terminal").Terminal
local lazygit = Terminal:new({ cmd = "lazygit", hidden = true })
function _LAZYGIT_TOGGLE()
	lazygit:toggle()
end

-- vim.api.nvim_set_keymap('n', '<leader>gg', '<ESC><cmd>lua _LAZYGIT_TOGGLE()<CR>', {noremap = true})
