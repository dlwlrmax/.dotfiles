return {
	"echasnovski/mini.nvim",
	version = "*",
	config = function()
		require("mini.pairs").setup()
        require("mini.ai").setup()
        require("mini.surround").setup({
            mapping = {
                add = "ya",
                delete = "yd",
                find = "yf",
                find_left = "yF",
                highlight = "yh",
                replace = "yr",
                update_n_lines = "yn",
            }
        })
		require("mini.cursorword").setup()

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
}
