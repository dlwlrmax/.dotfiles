return {
	"nvimdev/lspsaga.nvim",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-tree/nvim-web-devicons",
	},
	after = "nvim-lspconfig",
	config = function()
		require("lspsaga").setup({
			code_action = {
				show_server_name = true,
				extend_gitsigns = true,
				keys = {
					quit = "q",
					exec = "<CR>",
				},
			},
			rename = {
				in_select = false,
				keys = {
					quit = "q",
					exec = "<CR>",
				},
			},
			outline = {
				auto_close = true,
				close_after_jump = true,
				layout = "float",
				keys = {
					quit = "q",
					toggle = "o",
				},
			},
			definition = {
				keys = {
					quit = "q",
					edit = "<CR>",
					vsplit = "<C-v>",
					split = "<C-x>",
				},
			},
			lightbulb = {
				enable = false,
			},
		})
		vim.keymap.set("n", "<leader>ca", "<cmd>Lspsaga code_action<CR>")
		vim.keymap.set("n", "<leader>K", "<cmd>Lspsaga hover_doc<CR>")
		vim.keymap.set("n", "<leader>rn", "<cmd>Lspsaga rename<CR>")
		vim.keymap.set("n", "<leader>kk", "<cmd>Lspsaga peek_type_definition<CR>")
		vim.keymap.set("n", "grf", "<cmd>Lspsaga finder<CR>")
		vim.keymap.set("n", "gD", "<cmd>Lspsaga peek_definition<CR>")
		vim.keymap.set("n", "gt", "<cmd>Lspsaga peek_type_definition<CR>")
		vim.keymap.set("n", "gd", "<cmd>Lspsaga goto_definition<CR>")
		vim.keymap.set("n", "dp", "<cmd>Lspsaga diagnostic_jump_prev<CR>")
		vim.keymap.set("n", "dn", "<cmd>Lspsaga diagnostic_jump_next<CR>")
	end,
}
