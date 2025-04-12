return {
	{
		"echasnovski/mini.nvim",
		version = "*",
		config = function()
			local hipatterns = require("mini.hipatterns")
			hipatterns.setup({
				highlighters = {
					-- Highlight standalone 'FIXME', 'HACK', 'TODO', 'NOTE'
					fixme = { pattern = "%f[%w]()FIXME()%f[%W]", group = "MiniHipatternsFixme" },
					hack = { pattern = "%f[%w]()HACK()%f[%W]", group = "MiniHipatternsHack" },
					todo = { pattern = "%f[%w]()TODO()%f[%W]", group = "MiniHipatternsTodo" },
					note = { pattern = "%f[%w]()NOTE()%f[%W]", group = "MiniHipatternsNote" },

					-- Highlight hex color strings (`#rrggbb`) using that color
					hex_color = hipatterns.gen_highlighter.hex_color(),
				},
			})

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
					go_in = "l",
					go_in_plus = "L",
					go_out = "h",
					go_out_plus = "H",
					mark_goto = "'",
					mark_set = "m",
					reset = "<BS>",
					reveal_cwd = "@",
					show_help = "g?",
					synchronize = "<CR>",
					trim_left = "<",
					trim_right = ">",
				},
			})
		end,
	},
}
