-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set
local api = vim.api

map({ "i" }, "jj", "<ESC>", { desc = "Quick Escape" })
map({ "n" }, "<leader>w", ":w!<CR>", { desc = "Save File", silent = true })

-- Buffers
map("n", "<M-h>", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
map("n", "<M-l>", "<cmd>bnext<cr>", { desc = "Next Buffer" })

-- Movement
map("n", "<S-h>", "^", { desc = "Prev Buffer" })
map("n", "<S-l>", "$", { desc = "Next Buffer" })
map("n", "<leader>l", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })

-- Default
map('n', '<C-q>', 'q', { noremap = true })
map('n', 'q', '<Nop>', { noremap = true })

-- Replace
map('n', '<leader>rp', [[:%s/<C-r><C-w>//gIc<Left><Left><Left><Left>]], { silent = false, desc = "Replace word under cursor"})
