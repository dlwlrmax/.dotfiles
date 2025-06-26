return {
	{
		"echasnovski/mini.nvim",
		version = "*",
		config = function()
			local miniDiff = require("mini.diff")
			miniDiff.setup({
				view = {
					priority = 0,
				},
				mappings = {
					--- Remove all mappings to avoid conflicts with other plugins and which key
					apply = "",
					reset = "",
					textobject = "",
					goto_first = "",
					goto_prev = "",
					goto_next = "",
					goto_last = "",
				},
			})

			vim.keymap.set("n", "<leader>gg", function()
				miniDiff.toggle_overlay(0)
			end, { noremap = true, silent = true, desc = "Toggle MiniDiff overlay" })
			require("mini.pairs").setup()
			require("mini.icons").setup()
			require("mini.cursorword").setup({
				delay = 100,
			})

			require("mini.surround").setup({
				mappings = {
					add = "ya", -- Add surrounding in Normal and Visual modes
					delete = "yd", -- Delete surrounding
					find = "yf", -- Find surrounding (to the right)
					find_left = "yF", -- Find surrounding (to the left)
					highlight = "yh", -- Highlight surrounding
					replace = "yr", -- Replace surrounding
					update_n_lines = "yn", -- Update `n_lines`

					suffix_last = "l", -- Suffix to search with "prev" method
					suffix_next = "n", -- Suffix to search with "next" method
				},
			})
			vim.api.nvim_set_keymap(
				"n",
				"<leader>ya",
				"yaiw",
				{ noremap = false, silent = true, desc = "Quick surround WORD" }
			)
		end,
	},
	{
		"echasnovski/mini.files",
		version = "*",
		keys = {
			{
				"-",
				function()
					require("mini.files").open(vim.api.nvim_buf_get_name(0))
				end,
				desc = "Open File Browser",
				mode = "n",
			},
		},
		config = function()
			require("mini.files").setup({
				mappings = {
					close = "q",
                    go_in = "L",
					go_in_plus = "L",
					go_out_plus = "H",
                    go_out = "H",
					mark_goto = "'",
					mark_set = "m",
					reset = "<BS>",
					reveal_cwd = "@",
					show_help = "g?",
					synchronize = "<CR>",
					trim_left = "<",
					trim_right = ">",
				},
                windows = {
                    preview = true,
                    width_preview = 40
                }
			})
		end,
	},
}
