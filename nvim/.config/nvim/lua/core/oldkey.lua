vim.keymap.set("n", "<leader>og", function()
	vim.api.nvim_echo({ { "⚡<leader>go <- <leader>og" } }, false, {})
end, { desc = "[OLD] lazygit" })
