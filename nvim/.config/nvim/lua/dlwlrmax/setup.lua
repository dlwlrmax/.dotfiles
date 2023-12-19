local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)
-- Example using a list of specs with the default options
vim.g.mapleader = " " -- Make sure to set `mapleader` before lazy so your mappings are correct

local plugins = {
	{
		"catppuccin/nvim",
		name = "catppuccin",
		priority = 1000,
		config = function()
			require("catppuccin").setup({ background = { dark = "macchiato" } })
			vim.cmd.colorscheme("catppuccin")
		end,
	},
	{ "nvim-lua/plenary.nvim" },
	{ "christoomey/vim-tmux-navigator" },
	{ "inkarkat/vim-ReplaceWithRegister" },
	{
		"numToStr/Comment.nvim",
		opts = {
			-- add any options here
		},
		lazy = false,
	},
	{ "nvim-tree/nvim-web-devicons" },
	{ "nvim-lualine/lualine.nvim", event = "VeryLazy" },
	{ "nvim-lua/popup.nvim" },
	{
		"hrsh7th/nvim-cmp",
		dependencies = {
			"hrsh7th/cmp-emoji",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-path",
			"hrsh7th/cmp-cmdline",
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-nvim-lsp-document-symbol",
			"lukas-reineke/cmp-under-comparator",
		},
	},
	{
		"L3MON4D3/LuaSnip",
		dependencies = { "rafamadriz/friendly-snippets" },
		-- follow latest release.
		version = "2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
		-- install jsregexp (optional!).
		build = "make install_jsregexp",
		keys = function()
			return {}
		end,
	},
	{
		"tzachar/cmp-tabnine",
		build = "./install.sh",
		dependencies = "hrsh7th/nvim-cmp",
	},
	{ "saadparwaiz1/cmp_luasnip" },
	{
		"williamboman/mason.nvim",
	},
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
	},
	{
		"nvimtools/none-ls.nvim",
		event = { "BufReadPre", "BufNewFile" },
	},
	{ "lukas-reineke/indent-blankline.nvim", main = "ibl", opts = {} },
	{
		"nvimdev/lspsaga.nvim",
		dependencies = {
			"nvim-treesitter/nvim-treesitter", -- optional
			"nvim-tree/nvim-web-devicons", -- optional
			"nvim-treesitter/nvim-treesitter-textobjects",
			"nvim-treesitter/nvim-treesitter-context",
		},
	},
	{ "windwp/nvim-ts-autotag" },
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		opts = {
			check_ts = true,
			ts_config = {
				lua = { "string" }, -- it will not add pair on that treesitter node
				javascript = { "template_string" },
				java = false, -- don't check treesitter on java
			},
		}, -- this is equalent to setup({}) function
	},
	{ "lewis6991/gitsigns.nvim" },
	{ "jose-elias-alvarez/typescript.nvim" },
	{ "onsails/lspkind.nvim" },
	{
		"romgrk/barbar.nvim",
		dependencies = {
			"lewis6991/gitsigns.nvim", -- OPTIONAL: for git status
			"nvim-tree/nvim-web-devicons", -- OPTIONAL: for file icons
		},
		init = function()
			vim.g.barbar_auto_setup = false
		end,
		opts = {
			-- lazy.nvim will automatically call setup for you. put your options here, anything missing will use the default:
			-- animation = true,
			-- insert_at_start = true,
			-- …etc.
		},
		version = "^1.0.0", -- optional: only update when a new 1.x version is released
	},
	{ "mhinz/vim-startify" },
	-- {
	-- 	"ray-x/lsp_signature.nvim",
	-- 	event = "VeryLazy",
	-- 	opts = {
	-- 		bind = true,
	-- 		handler_opts = {
	-- 			border = "rounded",
	-- 		},
	-- 	},
	-- 	config = function(_, opts)
	-- 		require("lsp_signature").setup(opts)
	-- 	end,
	-- },
	{ "m-demare/hlargs.nvim" },
	{ "winston0410/cmd-parser.nvim" },
	{ "ThePrimeagen/harpoon" },
	{ "uga-rosa/translate.nvim" },
	{ "kevinhwang91/nvim-ufo", dependencies = { "kevinhwang91/promise-async" } },
	{ "petertriho/nvim-scrollbar" },
	{
		"simrat39/symbols-outline.nvim",
	},
	{
		"NeogitOrg/neogit",
		dependencies = {
			"nvim-lua/plenary.nvim", -- required
			"nvim-telescope/telescope.nvim", -- optional
			"sindrets/diffview.nvim", -- optional
			"ibhagwan/fzf-lua", -- optional
		},
		config = true,
	},
	{ "folke/flash.nvim" },
	{ "kevinhwang91/nvim-hlslens" },
	-- mini stuff
	{
		"echasnovski/mini.animate",
		version = "*",
		config = function()
			require("mini.animate").setup({
				resize = {
					enable = false,
				},
				open = {
					enable = false,
				},
				close = {
					enable = false,
				},
				scroll = {
					enable = false,
				},
			})
		end,
	},
	{
		"echasnovski/mini.cursorword",
		version = "*",
		config = function()
			require("mini.cursorword").setup()
		end,
	},
	{
		"echasnovski/mini.surround",
		version = "*",
		config = function()
			require("mini.surround").setup({
				mappings = {
					add = "ya", -- Add surrounding in Normal and Visual modes
					delete = "yd", -- Delete surrounding
					find = "", -- Find surrounding (to the right)
					find_left = "", -- Find surrounding (to the left)
					highlight = "yh", -- Highlight surrounding
					replace = "yr", -- Replace surrounding
					update_n_lines = "yn", -- Update `n_lines`

					suffix_last = "l", -- Suffix to search with "prev" method
					suffix_next = "n", -- Suffix to search with "next" method
				},
			})
		end,
	},
	{
		"nvim-telescope/telescope.nvim",
		tag = "0.1.3",
		dependencies = { "nvim-lua/plenary.nvim" },
	},
	{
		"nvim-telescope/telescope-fzf-native.nvim",
		build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build",
	},
	{ "smartpde/telescope-recent-files" },
	{
		"j-hui/fidget.nvim",
		tag = "legacy",
		event = "LspAttach",
		opts = {
			-- options
		},
	},
	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v3.x",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
			"MunifTanjim/nui.nvim",
		},
	},
	-- { "MunifTanjim/nui.nvim" },
	{ "folke/which-key.nvim" },
	{
		"mg979/vim-visual-multi",
		branch = "master",
	},
	{ "akinsho/toggleterm.nvim", version = "*", config = true },
	{
		"junegunn/fzf",
		build = function()
			vim.fn["fzf#install"]()
		end,
	},
	{
		"linrongbin16/fzfx.nvim",
		dependencies = { "junegunn/fzf" },
		config = function()
			require("fzfx").setup()
		end,
	},
	{
		"danymat/neogen",
		dependencies = "nvim-treesitter/nvim-treesitter",
		config = true,
	},
	{
		"zbirenbaum/copilot.lua",
		cmd = "Copilot",
		event = "InsertEnter",
		config = function()
			require("copilot").setup({
				suggestion = {
					enabled = true,
					auto_trigger = true,
					debounce = 50,
					keymap = {
						accept = "<M-l>",
						next = "<M-j>",
						prev = "<M-k>",
						dismiss = "<M-h>",
					},
				},
			})
		end,
	},
	{
		"folke/noice.nvim",
		event = "VeryLazy",
		opts = {
			cmdline = {
				format = {
					cmdline = {
						icon = "󰅬",
					},
				},
			},
			views = {
				cmdline_popup = {
					position = {
						row = 5,
						col = "50%",
					},
					size = {
						height = "auto",
						width = 60,
					},
				},
				popupmenu = {
					relative = "editor",
					position = {
						row = 8,
						col = "50%",
					},
					size = {
						width = 60,
						height = 10,
					},
					border = {
						style = "rounded",
						padding = { 0, 1 },
					},
					win_options = {
						winhighlight = { Normal = "Normal", FloatBorder = "DiagnosticInfo" },
					},
				},
			},
			routes = {
				{
					filter = {
						event = "msg_show",
						kind = "",
						find = "written",
					},
					opts = { skip = true },
				},
			},
			lsp = {
				-- override markdown rendering so that **cmp** and other plugins use **Treesitter**
				override = {
					["vim.lsp.util.convert_input_to_markdown_lines"] = true,
					["vim.lsp.util.stylize_markdown"] = true,
					["cmp.entry.get_documentation"] = true,
				},
				progress = {
					enabled = false,
				},
			},
			messages = {
				view_search = false,
			},
			-- you can enable a preset for easier configuration
			presets = {
				bottom_search = false, -- use a classic bottom cmdline for search
				command_palette = true, -- position the cmdline and popupmenu together
				long_message_to_split = true, -- long messages will be sent to a split
				inc_rename = false, -- enables an input dialog for inc-rename.nvim
				lsp_doc_border = true, -- add a border to hover docs and signature help
			},
		},
		dependencies = {
			-- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
			"MunifTanjim/nui.nvim",
			-- OPTIONAL:
			--   `nvim-notify` is only needed, if you want to use the notification view.
			--   If not available, we use `mini` as the fallback
			"rcarriga/nvim-notify",
		},
	},
	{
		"rcarriga/nvim-notify",
		event = "VeryLazy",
		config = function()
			require("notify").setup({
				background_colour = "#000000",
			})
		end,
	},
	{
		"nvim-neorg/neorg",
		build = ":Neorg sync-parsers",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			require("neorg").setup({
				load = {
					["core.defaults"] = {},
					["core.concealer"] = {},
					["core.qol.todo_items"] = {},
					["core.dirman"] = {
						config = {
							workspaces = {
								notes = "~/notes",
							},
							default_workspace = "notes",
						},
					},
				},
			})

			vim.wo.foldlevel = 99
			vim.wo.conceallevel = 2
		end,
	},
}
local opts = {}
require("lazy").setup(plugins, opts)
