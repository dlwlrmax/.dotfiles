vim.keymap.set("n", "<leader>gg", function()
	vim.api.nvim_echo({ { "⚡<leader>go <- <leader>gg" } }, false, {})
end, { desc = "[OLD] Quit file" })

vim.keymap.set("n", "<leader>og", function()
	vim.api.nvim_echo({ { "⚡<leader>go <- <leader>og" } }, false, {})
end, { desc = "[OLD] lazygit" })
