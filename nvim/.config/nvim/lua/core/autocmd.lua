---- This file is automatically loaded by plugins.init
local function augroup(name)
  return vim.api.nvim_create_augroup("lazyvim_" .. name, { clear = true })
end
-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup("highlight_yank"),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Check if we need to reload the file when it changed
-- vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
--   group = augroup("checktime"),
--   command = "checktime",
-- })

-- config filetypes
local api = vim.api
local opt = vim.opt
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "php", "lua" },
  callback = function()
    opt.shiftwidth = 4
    opt.tabstop = 4
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "javascript", "typescript", "txt", "css", "scss" },
  callback = function()
    opt.shiftwidth = 2
    opt.tabstop = 2
  end,
})

vim.api.nvim_create_autocmd({"BufWritePost"}, {
    callback = function ()
        require('lint').try_lint()
    end
})
