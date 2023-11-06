-- config filetypes
local api = vim.api
local opt = vim.opt
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "php" },
	callback = function()
		opt.shiftwidth = 4
		opt.tabstop = 4
	end,
})
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "javascript", "typescript", "html", "txt", "css", "scss" },
	callback = function()
		opt.shiftwidth = 2
		opt.tabstop = 2
	end,
})
