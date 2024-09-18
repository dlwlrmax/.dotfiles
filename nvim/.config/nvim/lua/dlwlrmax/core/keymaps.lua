vim.g.mapleader = " "
local opts = {}
local keymap = vim.keymap
local api = vim.api

keymap.set("i", "jj", "<ESC>")
keymap.set("n", "<leader>w", ":w!<cr>")
keymap.set("n", "<leader>fq", ":q!<cr>")
keymap.set("n", "<leader>y", ":+y<cr>")
keymap.set("n", "<leader><cr>", ":noh<cr>")
keymap.set("n", "<leader>fw", "/")
keymap.set("n", "<A-f>", "/")
keymap.set("n", "<A-p>", "/")
keymap.set("n", "<C-f>", "/")
keymap.set("n", "n", "nzzzv")
keymap.set("n", "N", "Nzzzv")
keymap.set("v", "<", "<gv")
keymap.set("v", ">", ">gv")
-- keymap.set("n", "J", "mzJ`z");
keymap.set("i", ",", ",<C-g>u")
keymap.set("i", ".", ".<C-g>u")
keymap.set("v", "J", ":m '>+1<CR>gv=gv")
keymap.set("v", "K", ":m '<=2<CR>gv=gv")
keymap.set("n", "J", ":m .+1<CR>==")
keymap.set("n", "K", ":m .-2<CR>==")
keymap.set("n", "H", "^")
keymap.set("n", "L", "$")
-- keymap.set("n", "<leader>bd", ":BClose<cr>:tabclose<cr>gT");
-- bufferline
keymap.set("n", "<leader>h", "<Cmd>BufferLineCyclePrev<CR><CR>")
keymap.set("n", "<leader>l", "<Cmd>BufferLineCycleNext<CR>")
keymap.set("n", "<leader>ml", "<Cmd>BufferLineMoveNext<CR><CR>")
keymap.set("n", "<leader>mh", "<Cmd>BufferLineMovePrev<CR>")
keymap.set("n", "<C-w>", "<Cmd>bd<CR>")
keymap.set("n", "<Leader>rt", "<Cmd>BufferRestore<CR>")
keymap.set("n", "<leader>q", "<Cmd>b#<CR>")
keymap.set("n", "<leader>rr", "<Cmd>BufferLineCloseOthers<CR>")
keymap.set("n", "<leader>bo", "<Cmd>BufferLinePick<CR>")
keymap.set("n", "<leader>bO", "<Cmd>BufferLinePick<CR>")

--Nvim Tree
keymap.set("n", "<leader>e", "<CMD>Neotree toggle<CR>")
keymap.set("n", "<leader>b", "<CMD>Neotree focus<CR>")
-- keymap.set("n", "<leader>e", ":Neotree source=filesystem reveal=true position=right<cr>");

--Telescope
-- keymap.set("n", "<C-e>", "<cmd>Telescope find_files<cr>");
keymap.set("n", "<leader><space>", "<cmd>Telescope resume<cr>")
keymap.set("n", "<leader>fa", "<cmd>Telescope find_files<cr>")
keymap.set("n", "<leader>ff", "<cmd>Telescope find_files hidden=true<cr>")
keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep<cr>")
keymap.set("n", "<leader>fc", "<cmd>Telescope live_grep hidden=true<cr>")
keymap.set("n", "<leader>km", "<cmd>Telescope keymaps<cr>")
keymap.set("v", "<leader>fs", "<cmd>Telescope grep_string<cr>")
keymap.set("n", "?", "<cmd>Telescope live_grep<cr>")
keymap.set("v", "<leader>fc", "<cmd>Telescope grep_string hidden=true<cr>")
keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>")
keymap.set("n", "<leader>fh", "<cmd>Telescope help_tags<cr>")

--Format
api.nvim_set_keymap(
	"n",
	"<leader>nf",
	"<ESC><cmd>lua vim.lsp.buf.format({ timeout_ms = 2000 })<CR>",
	{ noremap = true }
)
api.nvim_set_keymap("v", "<leader>nf", "<ESC><cmd>lua vim.lsp.buf.range_formatting()<CR>", { noremap = true })

--Gitsigns
keymap.set("n", "<leader>gn", "<cmd>Gitsigns next_hunk<cr>")
keymap.set("n", "<leader>gp", "<cmd>Gitsigns prev_hunk<cr>")
keymap.set("n", "<leader>ph", "<CMD>Gitsigns preview_hunk<CR>")

-- Translate
keymap.set("n", "<leader>t", "<Cmd>Translate EN<CR>")

keymap.set("n", "<leader>rr", "<CMD>%bd|e#<CR>", { desc = "Close all buffer but current" })

-- Oils
keymap.set("n", "-", "<CMD>Oil --float<CR>", { desc = "Open oil" })

local opts = { noremap = true, silent = true }

-- set keybinds
keymap.set("n", "gr", "<cmd>Lspsaga finder<CR>", opts) -- show definition, references
-- keymap.set("n", "gD", "<Cmd>lua vim.lsp.buf.declaration()<CR>", opts) -- got to declaration
keymap.set("n", "gD", "<cmd>Lspsaga peek_definition<CR>", opts) -- see definition and make edits in window
keymap.set("n", "gd", "<cmd>Lspsaga goto_definition<CR>", opts) -- see definition and make edits in window
keymap.set("n", "gt", "<cmd>Lspsaga peek_type_definition<CR>", opts) -- see definition and make edits in window
keymap.set("n", "<leader>kk", "<cmd>Lspsaga peek_type_definition<CR>", opts) -- see definition and make edits in window
keymap.set("n", "<leader>K", "<cmd>Lspsaga hover_doc<CR>", opts) -- show documentation for what is under cursor
-- keymap.set("n", "gt", "<cmd>Lspsaga goto_type_definition<CR>", opts) -- see definition and make edits in window

keymap.set("n", "<leader>sl", "<cmd>Lspsaga show_line_diagnostics<CR>", opts)

-- Like show_line_diagnostics, it supports passing the ++unfocus argument
keymap.set("n", "<leader>sc", "<cmd>Lspsaga show_cursor_diagnostics<CR>", opts)

-- Show buffer diagnostics
keymap.set("n", "<leader>sb", "<cmd>Lspsaga show_buf_diagnostics<CR>", opts)

keymap.set("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts) -- go to implementation
keymap.set("n", "<leader>ca", "<cmd>Lspsaga code_action<CR>", opts) -- see available code actions
keymap.set("n", "<leader>rn", "<cmd>Lspsaga rename<CR>", opts) -- smart rename
keymap.set("n", "<leader>dd", "<cmd>Lspsaga show_line_diagnostics<CR>", opts) -- show  diagnostics for line
keymap.set("n", "<leader>dD", "<cmd>Lspsaga show_cursor_diagnostics<CR>", opts) -- show diagnostics for cursor
keymap.set("n", "dp", "<cmd>Lspsaga diagnostic_jump_prev<CR>", opts) -- jump to previous diagnostic in buffer
keymap.set("n", "dn", "<cmd>Lspsaga diagnostic_jump_next<CR>", opts) -- jump to next diagnostic in buffer
keymap.set("n", "<leader>o", "<cmd>Lspsaga outline<CR>", opts) -- see outline on right hand side
