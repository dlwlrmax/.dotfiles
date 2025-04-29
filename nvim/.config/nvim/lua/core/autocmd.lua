---- This file is automatically loaded by plugins.init
local function augroup(name)
	return vim.api.nvim_create_augroup("lazyvim_" .. name, { clear = true })
end

-- Check if we need to reload the file when it changed
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave", "BufEnter" }, {
	group = augroup("checktime"),
	callback = function()
		if vim.o.buftype ~= "nofile" then
			vim.cmd("checktime")
		end
	end,
})

vim.api.nvim_create_autocmd({ "VimResized" }, {
	group = augroup("resize_splits"),
	callback = function()
		local current_tab = vim.fn.tabpagenr()
		vim.cmd("tabdo wincmd =")
		vim.cmd("tabnext " .. current_tab)
	end,
})

-- config filetypes
local api = vim.api
local opt = vim.opt
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "php", "lua" },
	callback = function()
		opt.shiftwidth = 4
		opt.tabstop = 4
		opt.expandtab = true
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "javascript", "typescript", "txt", "css", "scss" },
	callback = function()
		opt.shiftwidth = 2
		opt.tabstop = 2
		opt.expandtab = true
	end,
})


-- close some filetypes with <q>
vim.api.nvim_create_autocmd("FileType", {
	group = augroup("close_with_q"),
	pattern = {
		"PlenaryTestPopup",
		"checkhealth",
		"dbout",
		"gitsigns-blame",
		"grug-far",
		"help",
		"lspinfo",
		"neotest-output",
		"neotest-output-panel",
		"neotest-summary",
		"notify",
		"qf",
		"snacks_win",
		"Avante",
		"AvanteInput",
		"spectre_panel",
		"startuptime",
		"tsplayground",
	},
	callback = function(event)
		vim.bo[event.buf].buflisted = false
		vim.schedule(function()
			vim.keymap.set("n", "q", function()
				vim.cmd("close")
				pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
			end, {
				buffer = event.buf,
				silent = true,
				desc = "Quit buffer",
			})
		end)
	end,
})

-- wrap and check for spell in text filetypes
vim.api.nvim_create_autocmd("FileType", {
	group = augroup("wrap_spell"),
	pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
	callback = function()
		vim.opt_local.wrap = true
		vim.opt_local.spell = true
	end,
})

-- Auto create dir when saving a file, in case some intermediate directory does not exist
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
	group = augroup("auto_create_dir"),
	callback = function(event)
		if event.match:match("^%w%w+:[\\/][\\/]") then
			return
		end
		local file = vim.uv.fs_realpath(event.match) or event.match
		vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
	end,
})

-- -- Show diagnostics on hover
-- vim.api.nvim_create_autocmd({ "CursorHold" }, {
-- 	group = vim.api.nvim_create_augroup("float_diagnostic", { clear = true }),
-- 	callback = function()
-- 		vim.diagnostic.open_float(nil, {
-- 			focus = false,
-- 			border = "rounded",
-- 		})
-- 	end,
-- })
--
-- Laravel-ls
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "php", "blade" },
	callback = function()
		local root_dir = vim.fs.find("composer.json", { upward = true, stop = vim.loop.os_homedir() })[1]
		if root_dir then
			root_dir = vim.fn.fnamemodify(root_dir, ":h") -- Get the directory containing composer.json
			vim.lsp.start({
				name = "laravel-ls",
				cmd = { "laravel-ls" },
				root_dir = root_dir,
			})
		end
	end,
})
