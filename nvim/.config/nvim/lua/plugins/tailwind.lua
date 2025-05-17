-- tailwind-tools.lua
return {
	{
		"luckasRanarison/tailwind-tools.nvim",
		name = "tailwind-tools",
		build = ":UpdateRemotePlugins",
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			"neovim/nvim-lspconfig", -- optional
		},
		opts = {}, -- your configuration
        ft = { "html", "svelte", "astro", "vue", "typescriptreact", "php", "blade" },
	},
	-- {
	-- 	"razak17/tailwind-fold.nvim",
	-- 	opts = {},
	-- 	dependencies = { "nvim-treesitter/nvim-treesitter" },
	-- 	ft = { "html", "svelte", "astro", "vue", "typescriptreact", "php", "blade" },
	-- },
}
