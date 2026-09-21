-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Close Diffview before Neovim exits
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    if vim.fn.exists(":DiffviewClose") == 2 then
      vim.cmd("DiffviewClose")
    end
  end,
})

-- `q` is globally disabled in config/keymaps.lua; restore it where it
-- natively closes a window/pager.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("UserNativeQ", { clear = true }),
  pattern = {
    "checkhealth",
    "dap-repl",
    "help",
    "lazy",
    "lspinfo",
    "man",
    "mason",
    "noice",
    "notify",
    "qf",
    "trouble",
  },
  callback = function(ev)
    vim.keymap.set("n", "q", "q", { buffer = ev.buf, desc = "Close Window" })
  end,
})
