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

-- Disable swapfile
vim.opt.swapfile = false

vim.o.winborder = 'rounded'
