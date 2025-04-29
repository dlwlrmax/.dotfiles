return {
	"nvimdev/lspsaga.nvim",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-tree/nvim-web-devicons",
	},
	after = "nvim-lspconfig",
	keys = {
		{
			"<leader>ca",
			"<cmd>Lspsaga code_action<CR>",
			desc = "[Saga]Code Action",
			mode = "n",
			silent = true,
			noremap = true,
		},
		{
			"<leader>K",
			"<cmd>Lspsaga hover_doc<CR>",
			desc = "[Saga]Hover",
			mode = "n",
			silent = true,
			noremap = true,
		},
		{
			"<leader>rn",
			"<cmd>Lspsaga rename<CR>",
			desc = "[Saga]Rename",
			mode = "n",
			silent = true,
			noremap = true,
		},
		{
			"<leader>kk",
			"<cmd>Lspsaga peek_type_definition<CR>",
			desc = "[Saga]Peek Type Definition",
			mode = "n",
			silent = true,
			noremap = true,
		},
		{
			"grf",
			"<cmd>Lspsaga finder<CR>",
			desc = "[Saga]Finder",
			mode = "n",
			silent = true,
			noremap = true,
		},
		{
			"gd",
			"<cmd>Lspsaga peek_definition<CR>",
			desc = "[Saga]Goto Definition",
			mode = "n",
			silent = true,
			noremap = true,
		},
		{
			"gD",
			"<cmd>Lspsaga goto_definition<CR>",
			desc = "[Saga]Goto Definition",
			mode = "n",
			silent = true,
			noremap = true,
		},
		{
			"gt",
			"<cmd>Lspsaga peek_type_definition<CR>",
			desc = "[Saga]Goto Type Definition",
			mode = "n",
			silent = true,
			noremap = true,
		},
		{
			"dp",
			"<cmd>Lspsaga diagnostic_jump_prev<CR>",
			desc = "[Saga]Prev Diagnostic",
			mode = "n",
			silent = true,
			noremap = true,
		},
		{
			"dn",
			"<cmd>Lspsaga diagnostic_jump_next<CR>",
			desc = "[Saga]Next Diagnostic",
			mode = "n",
			silent = true,
			noremap = true,
		},
	},
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
                }
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
				enable = true,
				sign = false,
				debounce = 300,
				sign_priority = 40,
				virtual_text = true,
			},
		})
	end,
}
