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
	{
		"ThePrimeagen/harpoon",
		branch = "harpoon2",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			local harpoon = require("harpoon")

			-- REQUIRED
			harpoon:setup()
			-- REQUIRED

			vim.keymap.set("n", "<leader>a", function()
				harpoon:list():add()
			end)
			vim.keymap.set("n", "<C-e>", function()
				harpoon.ui:toggle_quick_menu(harpoon:list())
			end)

			vim.keymap.set("n", "<leader>1", function()
				harpoon:list():select(1)
			end)
			vim.keymap.set("n", "<leader>2", function()
				harpoon:list():select(2)
			end)
			vim.keymap.set("n", "<leader>3", function()
				harpoon:list():select(3)
			end)
			vim.keymap.set("n", "<leader>4", function()
				harpoon:list():select(4)
			end)

			-- Toggle previous & next buffers stored within Harpoon list
			vim.keymap.set("n", "<C-p>", function()
				harpoon:list():prev()
			end)
			vim.keymap.set("n", "<C-n>", function()
				harpoon:list():next()
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
			recipe = { "default", { animate = false } },
			ncmode = "buffers", -- use 'windows' to fade inactive windows
			fadelevel = 0.65, -- any value between 0 and 1. 0 is hidden and 1 is opaque.
			tint = {
				bg = { rgb = { 0, 0, 0 }, intensity = 0.3 }, -- adds 30% black to background
			},

			basebg = "",

			blocklist = {
				default = {
					buf_opts = { buftype = { "prompt", "terminal", "Avante", "grug-far", "snacks_win" } },
					win_config = { relative = true },
				},
			},
			link = {},
			groupdiff = true, -- links diffs so that they style together
			groupscrollbind = false, -- link scrollbound windows so that they style together.
			enablefocusfading = false,
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
}
