return {
	{
		"echasnovski/mini.nvim",
		version = "*",
		config = function()
			require("mini.pairs").setup()
			require("mini.ai").setup()
			require("mini.cursorword").setup()
			require("mini.icons").setup()
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

			vim.keymap.set("n", "go", function()
				miniDiff.toggle_overlay(0)
			end, { noremap = true, silent = true, desc = "Toggle MiniDiff overlay" })

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
		end,
	},
}
