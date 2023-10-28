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
	{ "tpope/vim-surround" },
	{ "inkarkat/vim-ReplaceWithRegister" },
	{
		"numToStr/Comment.nvim",
		opts = {
			-- add any options here
		},
		lazy = false,
	},
	{ "nvim-tree/nvim-web-devicons" },
	{ "nvim-lualine/lualine.nvim" },
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
	{ "williamboman/mason-lspconfig.nvim" },
	{
		"neovim/nvim-lspconfig",
	},
	{ "nvimtools/none-ls.nvim" },
	{ "jayp0521/mason-null-ls.nvim" },
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
		opts = {}, -- this is equalent to setup({}) function
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
	{
		"ray-x/lsp_signature.nvim",
		event = "VeryLazy",
		opts = {},
		config = function(_, opts)
			require("lsp_signature").setup(opts)
		end,
	},
	{ "m-demare/hlargs.nvim" },
	{ "winston0410/cmd-parser.nvim" },
	{ "NvChad/nvim-colorizer.lua" },
	{ "ThePrimeagen/harpoon" },
	{ "uga-rosa/translate.nvim" },
	{ "kevinhwang91/nvim-ufo", dependencies = { "kevinhwang91/promise-async" } },
	{ "petertriho/nvim-scrollbar" },
	{
		"stevearc/aerial.nvim",
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
	{ "sindrets/diffview.nvim" },
	{ "folke/flash.nvim" },
	{ "kevinhwang91/nvim-hlslens" },
	{ "yamatsum/nvim-cursorline" },
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
		{ "MunifTanjim/nui.nvim" },
		{ "folke/which-key.nvim" },
		{
			"roobert/search-replace.nvim",
			config = function()
				require("search-replace").setup({})
			end,
		},
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
	},
}
local opts = {}
require("lazy").setup(plugins, opts)
