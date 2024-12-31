vim.g.mapleader = " "
local keymap = vim.keymap
local api = vim.api

keymap.set("i", "jj", "<ESC>", { desc = "Quick Escape" })
keymap.set("n", "<leader>w", ":w!<cr>", { desc = "Save file" })
keymap.set("n", "<leader>fq", "<cmd>qall<cr>", { desc = "Quit file" })
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

--Nvim Tree
keymap.set("n", "<leader>e", "<CMD>Neotree toggle<CR>", { desc = "Toggle Nvim Tree" })
-- keymap.set("n", "<leader>e", ":Neotree source=filesystem reveal=true position=right<cr>");

keymap.set(
	"n",
	"<leader>F",
	"<cmd>lua require('grug-far').open({ prefills = { search = vim.fn.expand('<cword>') }})<cr>",
	{ desc = "GrugFar Live grep" }
)
keymap.set(
	"v",
	"<leader>fs",
	"<cmd>lua require('grug-far').with_visual_selection()<cr>",
	{ desc = "GrugFar Grep string" }
)

--Format
api.nvim_set_keymap("n", "<leader>i", "<ESC><cmd>lua vim.lsp.buf.format({ timeout_ms = 2000 })<CR>", { noremap = true })
-- keymap.set("n", "<leader>nf", "<cmd>lua require('conform').format()<CR>", { desc = "Format" })
-- api.nvim_set_keymap("v", "<leader>nf", "<ESC><cmd>lua vim.lsp.buf.range_formatting()<CR>", { noremap = true })

local opts = { noremap = true, silent = true }

-- set keybinds
keymap.set("n", "gr", "<cmd>Lspsaga finder<CR>", opts) -- show definition, references
keymap.set("n", "gD", "<cmd>Lspsaga goto_definition<CR>", opts) -- see definition and make edits in window
keymap.set("n", "gd", "<cmd>Lspsaga peek_definition<CR>", opts) -- see definition and make edits in window
keymap.set("n", "gt", "<cmd>Lspsaga peek_type_definition<CR>", opts) -- see definition and make edits in window
keymap.set("n", "<leader>kk", "<cmd>Lspsaga peek_type_definition<CR>", opts) -- see definition and make edits in window
keymap.set("n", "<leader>K", "<cmd>Lspsaga hover_doc<CR>", opts) -- show documentation for what is under cursor
keymap.set("n", "<leader>sl", "<cmd>Lspsaga show_line_diagnostics<CR>", opts)
keymap.set("n", "<leader>sc", "<cmd>Lspsaga show_cursor_diagnostics<CR>", opts)
keymap.set("n", "<leader>sb", "<cmd>Lspsaga show_buf_diagnostics<CR>", opts)
keymap.set("n", "<leader>ca", "<cmd>Lspsaga code_action<CR>", opts) -- see available code actions
keymap.set("n", "<leader>rn", "<cmd>Lspsaga rename<CR>", opts) -- smart rename
keymap.set("n", "dp", "<cmd>Lspsaga diagnostic_jump_prev<CR>", opts) -- jump to previous diagnostic in buffer
keymap.set("n", "dn", "<cmd>Lspsaga diagnostic_jump_next<CR>", opts) -- jump to next diagnostic in buffer
keymap.set("n", "<leader>op", "<cmd>Lspsaga outline<CR>", opts) -- see outline on right hand side

keymap.set("n", "<leader>F", "<cmd>GrugFar<CR>", { desc = "Find and replace" })

-- AI / Copilot Chat

-- Split
--
keymap.set("n", "<leader>-", "<C-W>s", { desc = "Vertical Split" })
keymap.set("n", "<leader>|", "<C-W>v", { desc = "Horizontal Split" })

-- Disable q for recording macros because it stop nvim-cmp
-- keymap.set("n", "q", "<Nop>", { silent = true })

-- Tab
keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "New tab" })
keymap.set("n", "<leader>tq", "<cmd>tabclose<CR>", { desc = "Close tab" })
keymap.set("n", "<leader>tp", "<cmd>tabprevious<CR>", { desc = "Previous tab" })
keymap.set("n", "<leader>tn", "<cmd>tabnext<CR>", { desc = "Next tab" })

-- Move split around
-- keymap.set("n", "<leader>wh", "<cmd>wincmd H<CR>", { desc = "Move left" })
keymap.set("n", "<leader>sx", "<cmd>wincmd J<CR>", { desc = "Move split vertical" })
-- keymap.set("n", "<leader>wk", "<cmd>wincmd K<CR>", { desc = "Move up" })
keymap.set("n", "<leader>sv", "<cmd>wincmd L<CR>", { desc = "Move split horizontal" })
