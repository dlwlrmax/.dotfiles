require("catppuccin").setup({
	flavour = "mocha", -- latte, frappe, macchiato, mocha
	background = { -- :h background
		light = "mocha",
		dark = "mocha",
	},
	transparent_background = false,
	term_colors = false,
	dim_inactive = {
		enabled = true,
		shade = "dark",
		percentage = 0.15,
	},
	styles = {
		comments = { "italic" },
		conditionals = { "bold" },
		loops = { "bold" },
		functions = { "italic", "bold" },
		keywords = { "italic" },
		booleans = { "bold" },
		operators = {},
		strings = {},
		variables = {},
		numbers = {},
		properties = { "bold" },
		types = { "bold" },
	},
	compile_path = vim.fn.stdpath("cache") .. "/catppuccin",
	default_integrations = true,
	integrations = {
		cmp = true,
		gitsigns = true,
		neotree = true,
        treesitter = true,
		neogit = true,
		telescope = true,
		native_lsp = {
			enabled = true,
			virtual_text = {
				errors = { "italic" },
				hints = { "italic" },
				warnings = { "italic" },
				information = { "italic" },
				ok = { "italic" },
			},
			underlines = {
				errors = { "underline" },
				hints = { "underline" },
				warnings = { "underline" },
				information = { "underline" },
			},
			inlay_hints = {
				background = true,
			},
		},
		which_key = true,
		indent_blankline = {
			enabled = true,
			colored_indent_levels = true,
		},
        lsp_trouble = true,
		mason = true,
        flash = true,
        grug_far = true,
		treesitter_context = true,
		notify = true,
        lsp_saga = true,
		mini = true,
		barbecue = {
			dim_context = true,
			alt_background = false,
			bold_basename = true,
			dim_dirname = true,
		},
        blink_cmp = true,
		beacon = true,
		harpoon = true,
		fidget = true,
        snacks = true,
		-- For more plugins integrations please scroll down (https://github.com/catppuccin/nvim#integrations)
	},
})

local status, _ = pcall(vim.cmd, "colorscheme catppuccin")
-- local status, _ = pcall(vim.cmd, "colorscheme dracula")
if not status then
	print("Colorscheme not found!")
	return
end
