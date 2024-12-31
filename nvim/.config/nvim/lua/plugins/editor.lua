return {
	{ "junegunn/fzf", build = "./install --bin" },
	{
		"ibhagwan/fzf-lua",
		-- optional for icon support
		dependencies = { "nvim-tree/nvim-web-devicons" },
		keys = {
			{
				"<leader><space>",
				"<cmd>lua require('fzf-lua').files()<cr>",
				desc = "FZF Files",
				mode = { "n" },
			},
			{
				"<C-e>",
				"<cmd>lua require('fzf-lua').oldfiles({ cwd_only = true })<cr>",
				desc = "FZF Oldfiles",
				mode = { "n" },
			},
			{
				"<leader>fw",
				"<cmd>lua require('fzf-lua').grep_cword()<cr>",
				desc = "FZF Grep Word",
				mode = { "v" },
			},
			{
				"<leader>fw",
				"<cmd>lua require('fzf-lua').live_grep()<cr>",
				desc = "FZF Live Grep",
				mode = { "n" },
			},
		},
		config = function()
			local img_previewer ---@type string[]?
			for _, v in ipairs({
				{ cmd = "ueberzug", args = {} },
				{ cmd = "chafa", args = { "{file}", "--format=symbols" } },
				{ cmd = "viu", args = { "-b" } },
			}) do
				if vim.fn.executable(v.cmd) == 1 then
					img_previewer = vim.list_extend({ v.cmd }, v.args)
					break
				end
			end
			-- calling `setup` is optional for customization
			require("fzf-lua").setup({
				fzf_colors = true,
				fzf_opts = {
					["--no-scrollbar"] = true,
				},
				defaults = {
					formatter = "path.dirname_first",
				},
				keys = {
					["<C-j>"] = "down",
					["<C-k>"] = "up",
					["<C-t>"] = "tabnew",
					["<C-v>"] = "vsplit",
					["<C-x>"] = "split",
				},
				previewers = {
					builtin = {
						extensions = {
							["png"] = img_previewer,
							["jpg"] = img_previewer,
							["jpeg"] = img_previewer,
							["gif"] = img_previewer,
							["webp"] = img_previewer,
						},
						ueberzug_scaler = "fit_contain",
					},
				},
				ui_select = function(fzf_opts, items)
					return vim.tbl_deep_extend("force", fzf_opts, {
						prompt = " ",
						winopts = {
							title = " " .. vim.trim((fzf_opts.prompt or "Select"):gsub("%s*:%s*$", "")) .. " ",
							title_pos = "center",
						},
					}, fzf_opts.kind == "codeaction" and {
						winopts = {
							layout = "vertical",
							-- height is number of items minus 15 lines for the preview, with a max of 80% screen height
							height = math.floor(math.min(vim.o.lines * 0.8 - 16, #items + 2) + 0.5) + 16,
							width = 0.5,
							preview = {
								layout = "vertical",
								vertical = "down:15,border-top",
							},
						},
					} or {
						winopts = {
							width = 0.5,
							-- height is number of items, with a max of 80% screen height
							height = math.floor(math.min(vim.o.lines * 0.8, #items + 2) + 0.5),
						},
					})
				end,
				winopts = {
					width = 0.8,
					height = 0.8,
					row = 0.5,
					col = 0.5,
					preview = {
						scrollchars = { "┃", "" },
					},
				},
			})
		end,
	},
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
	{
		"MagicDuck/grug-far.nvim",
		config = function()
			require("grug-far").setup({
				transient = true,
			})
		end,
	},
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
			end)
			vim.keymap.set("n", "<leader>2", function()
				ui.nav_file(2)
			end)
			vim.keymap.set("n", "<leader>3", function()
				ui.nav_file(3)
			end)
			vim.keymap.set("n", "<leader>4", function()
				ui.nav_file(4)
			end)
			vim.keymap.set("n", "<leader>5", function()
				ui.nav_file(5)
			end)
			vim.keymap.set("n", "<leader>6", function()
				ui.nav_file(6)
			end)
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
						guibg = "#44406e",
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
				bg = {rgb={0,0,0}, intensity=0.3}, -- adds 30% black to background
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
					-- buf_name = { "neotree" },
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
	-- {
	-- 	"lukas-reineke/indent-blankline.nvim",
	-- 	main = "ibl",
	-- 	opts = function()
	-- 		Snacks.toggle({
	-- 			name = "Indention Guides",
	-- 			get = function()
	-- 				return require("ibl.config").get_config(0).enabled
	-- 			end,
	-- 			set = function(state)
	-- 				require("ibl").setup_buffer(0, { enabled = state })
	-- 			end,
	-- 		}):map("<leader>ug")
	--
	-- 		return {
	-- 			indent = {
	-- 				char = "│",
	-- 				tab_char = "│",
	-- 			},
	-- 			scope = { show_start = false, show_end = false },
	-- 			exclude = {
	-- 				filetypes = {
	-- 					"Trouble",
	-- 					"alpha",
	-- 					"dashboard",
	-- 					"help",
	-- 					"lazy",
	-- 					"mason",
	-- 					"neo-tree",
	-- 					"notify",
	-- 					"snacks_dashboard",
	-- 					"snacks_notif",
	-- 					"snacks_terminal",
	-- 					"snacks_win",
	-- 					"toggleterm",
	-- 					"trouble",
	-- 				},
	-- 			},
	-- 		}
	-- 	end,
	-- },
}
