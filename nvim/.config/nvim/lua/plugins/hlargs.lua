return {
	"m-demare/hlargs.nvim",
	config = function()
        local hlargs = require("hlargs")
		hlargs.setup({
			color = "#FAAB78",
			highlight = {},
			excluded_filetypes = {},
			-- disable = function(lang, bufnr)
			--   return vim.tbl_contains(opts.excluded_filetypes, lang)
			-- end,
			paint_arg_declarations = true,
			paint_arg_usages = true,
			paint_catch_blocks = {
				declarations = false,
				usages = false,
			},
			extras = {
				named_parameters = false,
			},
			hl_priority = 10000,
			excluded_argnames = {
				declarations = {},
				usages = {
					python = { "self", "cls" },
					lua = { "self" },
				},
			},
			performance = {
				parse_delay = 100,
				slow_parse_delay = 200,
				max_iterations = 400,
				max_concurrent_partial_parses = 30,
				debounce = {
					partial_parse = 20,
					partial_insert_mode = 100,
					total_parse = 700,
					slow_parse = 5000,
				},
			},
		})

        hlargs.enable()
	end,
}
