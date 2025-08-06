-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set
local api = vim.api

map({ "i" }, "jj", "<ESC>", { desc = "Quick Escape" })
map({ "n" }, "<leader>w", ":w!<CR>", { desc = "Save File", silent = true })

-- Buffers line
map("n", "<M-h>", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
map("n", "<M-l>", "<cmd>bnext<cr>", { desc = "Next Buffer" })

-- Moverment
map("n", "<S-h>", "^", { desc = "Prev Buffer" })
map("n", "<S-l>", "$", { desc = "Next Buffer" })
map("n", "<leader>l", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })

-- Bufferline
map("n", "<leader>1", "<cmd>BufferLineGoToBuffer 1<cr>", { desc = "Go to buffer 1" })
map("n", "<leader>2", "<cmd>BufferLineGoToBuffer 2<cr>", { desc = "Go to buffer 2" })
map("n", "<leader>3", "<cmd>BufferLineGoToBuffer 3<cr>", { desc = "Go to buffer 3" })
map("n", "<leader>4", "<cmd>BufferLineGoToBuffer 4<cr>", { desc = "Go to buffer 4" })
map("n", "<leader>5", "<cmd>BufferLineGoToBuffer 5<cr>", { desc = "Go to buffer 5" })
