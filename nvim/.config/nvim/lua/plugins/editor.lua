return {
	{ "junegunn/fzf", build = "./install --bin" },
	{
		"folke/flash.nvim",
		event = "VeryLazy",
		---@type Flash.Config
		opts = {},
        -- stylua: ignore
        keys = {
            { "s",     mode = { "n", "x", "o" }, function() require("flash").jump() end,              desc = "Flash" },
            { "S",     mode = { "n", "x", "o" }, function() require("flash").treesitter() end,        desc = "Flash Treesitter" },
            { "r",     mode = "o",               function() require("flash").remote() end,            desc = "Remote Flash" },
            { "R",     mode = { "o", "x" },      function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
            { "<c-s>", mode = { "c" },           function() require("flash").toggle() end,            desc = "Toggle Flash Search" },
        },
	},
	-- {
	-- 	"MagicDuck/grug-far.nvim",
	-- 	config = function()
	-- 		require("grug-far").setup({
	-- 			transient = true,
	-- 		})
	-- 	end,
	-- },
	{
		"ThePrimeagen/harpoon",
		config = function()
			local harpoon = require("harpoon")
			harpoon.setup({})

			local mark = require("harpoon.mark")
			local ui = require("harpoon.ui")

			vim.keymap.set("n", "<leader>a", mark.add_file)
			-- vim.keymap.set("n", "<leader>re", "<CMD>Telescope harpoon marks theme=dropdown<CR>")
			vim.keymap.set("n", "<leader>rw", ui.toggle_quick_menu)
			vim.keymap.set("n", "<leader>re", ui.toggle_quick_menu)
			vim.keymap.set("n", "<leader>1", function()
				ui.nav_file(1)
			end, { desc = "Navigate to Harpoon Mark 1" })
			vim.keymap.set("n", "<leader>2", function()
				ui.nav_file(2)
			end, { desc = "Navigate to Harpoon Mark 2" })
			vim.keymap.set("n", "<leader>3", function()
				ui.nav_file(3)
			end, { desc = "Navigate to Harpoon Mark 3" })
			vim.keymap.set("n", "<leader>4", function()
				ui.nav_file(4)
			end, { desc = "Navigate to Harpoon Mark 4" })
			vim.keymap.set("n", "<leader>5", function()
				ui.nav_file(5)
			end, { desc = "Navigate to Harpoon Mark 5" })
			vim.keymap.set("n", "<leader>6", function()
				ui.nav_file(6)
			end, { desc = "Navigate to Harpoon Mark 6" })
			vim.keymap.set("n", "<leader>7", function()
				ui.nav_file(7)
			end, { desc = "Navigate to Harpoon Mark 7" })
		end,
	},
	{
		"b0o/incline.nvim",
		config = function()
			local helpers = require("incline.helpers")
			local devicons = require("nvim-web-devicons")
			require("incline").setup({
				window = {
					padding = 0,
					margin = { horizontal = 0 },
				},
				ignore = {
					filetypes = { "neo-tree" },
				},
				render = function(props)
					local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ":t")
					if filename == "" then
						filename = "[No Name]"
					end
					local ft_icon, ft_color = devicons.get_icon_color(filename)
					local modified = vim.bo[props.buf].modified
					return {
						ft_icon and { " ", ft_icon, " ", guibg = ft_color, guifg = helpers.contrast_color(ft_color) }
							or "",
						" ",
						{ filename, gui = modified and "bold,italic" or "bold" },
						" ",
						guibg = "#500073",
					}
				end,
			})
		end,
		-- Optional: Lazy load Incline
		event = "VeryLazy",
	},
	{
		"tadaa/vimade",
		-- default opts (you can partially set these or configure them however you like)
		opts = {
			-- Recipe can be any of 'default', 'minimalist', 'duo', and 'ripple'
			-- Set animate = true to enable animations on any recipe.
			-- See the docs for other config options.
			recipe = { "default", { animate = false } },
			ncmode = "buffers", -- use 'windows' to fade inactive windows
			fadelevel = 0.65, -- any value between 0 and 1. 0 is hidden and 1 is opaque.
			tint = {
				bg = { rgb = { 0, 0, 0 }, intensity = 0.3 }, -- adds 30% black to background
				-- fg = {rgb={0,0,255}, intensity=0.3}, -- adds 30% blue to foreground
				-- fg = {rgb={120,120,120}, intensity=1}, -- all text will be gray
				-- sp = {rgb={255,0,0}, intensity=0.5}, -- adds 50% red to special characters
				-- you can also use functions for tint or any value part in the tint object
				-- to create window-specific configurations
				-- see the `Tinting` section of the README for more details.
			},

			-- Changes the real or theoretical background color. basebg can be used to give
			-- transparent terminals accurating dimming.  See the 'Preparing a transparent terminal'
			-- section in the README.md for more info.
			-- basebg = [23,23,23],
			basebg = "",

			-- prevent a window or buffer from being styled. You
			blocklist = {
				default = {
					buf_opts = { buftype = { "prompt", "terminal", "Avante", "grug-far", "snacks_win" } },
					win_config = { relative = true },
					-- buf_vars = { variable = {'match1', 'match2'} },
					-- win_opts = { option = {'match1', 'match2' } },
					-- win_vars = { variable = {'match1', 'match2'} },
				},
				-- any_rule_name1 = {
				--   buf_opts = {}
				-- },
				-- only_behind_float_windows = {
				--   buf_opts = function(win, current)
				--     if (win.win_config.relative == '')
				--       and (current and current.win_config.relative ~= '') then
				--         return false
				--     end
				--     return true
				--   end
				-- },
			},
			-- Link connects windows so that they style or unstyle together.
			-- Properties are matched against the active window. Same format as blocklist above
			link = {},
			groupdiff = true, -- links diffs so that they style together
			groupscrollbind = false, -- link scrollbound windows so that they style together.

			-- enable to bind to FocusGained and FocusLost events. This allows fading inactive
			-- tmux panes.
			enablefocusfading = false,

			-- when nohlcheck is disabled the highlight tree will always be recomputed. You may
			-- want to disable this if you have a plugin that creates dynamic highlights in
			-- inactive windows. 99% of the time you shouldn't need to change this value.
			nohlcheck = true,
		},
	},
	{
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
	},
	{
		"axkirillov/hbac.nvim",
		config = function()
			require("hbac").setup({
				autoclose = true,
				threshold = 20,
				close_command = function(bufnr)
					vim.api.nvim_buf_delete(bufnr, {})
				end,
				close_buffers_with_windows = false,
				telescope = {},
			})
		end,
	},
	{
		"nvzone/showkeys",
		cmd = "ShowkeysToggle",
		opts = {
			maxkeys = 5,
            show_count = true,
			position = "bottom-right",
		},
	}
}
