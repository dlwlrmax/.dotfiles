return {
	"akinsho/git-conflict.nvim",
	version = "*",
	config = function()
		require("git-conflict").setup({
			default_mappings = true,
			default_commands = true,
			disable_diagnostics = true,
			list_opener = "copen",
			highlights = {
				incoming = "DiffAdd",
				current = "DiffText",
			},
		})
		vim.keymap.set("n", "co", "<Plug>(git-conflict-ours)")
		vim.keymap.set("n", "ct", "<Plug>(git-conflict-theirs)")
		vim.keymap.set("n", "cb", "<Plug>(git-conflict-both)")
		vim.keymap.set("n", "c0", "<Plug>(git-conflict-none)")
		vim.keymap.set("n", "cp", "<Plug>(git-conflict-prev-conflict)")
		vim.keymap.set("n", "cn", "<Plug>(git-conflict-next-conflict)")
	end,
}
