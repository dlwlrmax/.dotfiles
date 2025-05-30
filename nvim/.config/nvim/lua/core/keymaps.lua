vim.g.mapleader = " "
local keymap = vim.keymap
local api = vim.api

keymap.set("i", "jj", "<ESC>", { desc = "Quick Escape" })
keymap.set("n", "<leader>w", ":w!<cr>", { desc = "Save file" })
keymap.set("n", "<leader>fq", function()
	local answer = vim.fn.confirm("Are you sure you want to quit?", "&Yes\n&No", 1)
	if answer == 1 then
		api.nvim_command("qall")
	end
end, { desc = "Quit file" })
keymap.set("n", "<leader>y", ":+y<cr>", { desc = "Yank line" })
keymap.set("n", "<leader><cr>", ":noh<cr>", { desc = "Clear highlights" })
keymap.set("n", "n", "nzzzv", { desc = "Center search result" })
keymap.set("n", "N", "Nzzzv", { desc = "Center search result" })
keymap.set("v", "<", "<gv", { desc = "Indent left" })
keymap.set("v", ">", ">gv", { desc = "Indent right" })
-- keymap.set("n", "J", "mzJ`z");
keymap.set("i", ",", ",<C-g>u", { desc = "Undo comma" })
keymap.set("i", ".", ".<C-g>u", { desc = "Undo period" })
keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
keymap.set("v", "K", ":m '<=2<CR>gv=gv", { desc = "Move line up" })
keymap.set("n", "J", ":m .+1<CR>==", { desc = "Move line down" })
keymap.set("n", "K", ":m .-2<CR>==", { desc = "Move line up" })
keymap.set("n", "H", "^", { desc = "Move to start of line" })
keymap.set("n", "L", "$", { desc = "Move to end of line" })
-- keymap.set("n", "<leader>bd", ":BClose<cr>:tabclose<cr>gT");

-- keymap.set(
-- 	"n",
-- 	"<leader>F",
-- 	"<cmd>lua require('grug-far').open({ prefills = { search = vim.fn.expand('<cword>') }})<cr>",
-- 	{ desc = "GrugFar Live grep" }
-- )
-- keymap.set(
-- 	"v",
-- 	"<leader>fs",
-- 	"<cmd>lua require('grug-far').with_visual_selection()<cr>",
-- 	{ desc = "GrugFar Grep string" }
-- )

--Format
api.nvim_set_keymap("n", "<leader>i", "<ESC><cmd>lua vim.lsp.buf.format({ timeout_ms = 2000 })<CR>", { noremap = true })
-- keymap.set("n", "<leader>nf", "<cmd>lua require('conform').format()<CR>", { desc = "Format" })
-- api.nvim_set_keymap("v", "<leader>nf", "<ESC><cmd>lua vim.lsp.buf.range_formatting()<CR>", { noremap = true })

local opts = { noremap = true, silent = true }

-- set keybinds
keymap.set("n", "<leader>sl", "<cmd>lua vim.diagnostic.open_float()<CR>", opts)
keymap.set("n", "dp", "<cmd>Lspsaga diagnostic_jump_prev<CR>", opts) -- jump to previous diagnostic in buffer
keymap.set("n", "dn", "<cmd>Lspsaga diagnostic_jump_next<CR>", opts) -- jump to next diagnostic in buffer

-- AI / Copilot Chat

-- Split
--
keymap.set("n", "<C-W>\\", "<C-W>|", { desc = "Maximize current window" })

-- Disable q for recording macros because it stop nvim-cmp
-- keymap.set("n", "q", "<Nop>", { silent = true })

-- Tab
keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "New tab" })
keymap.set("n", "<leader>tq", "<cmd>tabclose<CR>", { desc = "Close tab" })
keymap.set("n", "<leader>tp", "<cmd>tabprevious<CR>", { desc = "Previous tab" })
keymap.set("n", "<leader>tn", "<cmd>tabnext<CR>", { desc = "Next tab" })

keymap.set({ "n", "v" }, "<leader>rp", ':%s/', { noremap = true, silent = true, desc = "Replace word" })

-- Buffer keymap

