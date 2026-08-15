-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
-- Basic config

vim.api.nvim_set_hl(0, "SnacksIndent", { fg = "#4c4f69", bg = "NONE" })

-- Disable some default options
vim.g.autoformat = false

-- Set to "intelephense" to use intelephense instead of phpactor.
vim.g.lazyvim_php_lsp = "intelephense"

vim.diagnostic.config({ float = { border = "rounded" } })

-- Performance
vim.opt.swapfile = false
vim.opt.updatetime = 250
-- PERF: trim ShaDa (default '100,<50,s10 grew to ~150KB, ~15ms read at startup)
vim.opt.shada = "!,'50,<30,s5,h"

vim.o.winborder = 'rounded'
