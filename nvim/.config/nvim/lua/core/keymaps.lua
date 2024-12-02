vim.g.mapleader = " "
local keymap = vim.keymap
local api = vim.api

keymap.set("i", "jj", "<ESC>", { desc = "Quick Escape" })
keymap.set("n", "<leader>w", ":w!<cr>", { desc = "Save file" })
keymap.set("n", "<leader>fq", ":q!<cr>", { desc = "Quit file" })
keymap.set("n", "<leader>y", ":+y<cr>", { desc = "Yank line" })
keymap.set("n", "<leader><cr>", ":noh<cr>", { desc = "Clear highlights" })
keymap.set("n", "<leader>fw", "/", { desc = "Search" })
keymap.set("n", "<C-f>", "/", { desc = "Search" })
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
-- bufferline
keymap.set("n", "<leader>h", "<Cmd>BufferLineCyclePrev<CR><CR>", { desc = "Previous buffer" })
keymap.set("n", "<leader>l", "<Cmd>BufferLineCycleNext<CR>", { desc = "Next buffer" })
keymap.set("n", "<leader>ml", "<Cmd>BufferLineMoveNext<CR><CR>", { desc = "Move buffer right" })
keymap.set("n", "<leader>mh", "<Cmd>BufferLineMovePrev<CR>", { desc = "Move buffer left" })
keymap.set("n", "<Leader>rt", "<Cmd>BufferRestore<CR>", { desc = "Restore last closed buffer" })
keymap.set("n", "<leader>q", "<Cmd>b#<CR>", { desc = "Switch to last buffer" })
keymap.set("n", "<leader>rr", "<Cmd>Bwipeout<CR>", { desc = "Close all buffer but current" })
keymap.set("n", "<leader>P", "<Cmd>BufferLinePick<CR>", { desc = "Pick buffer" })

--Nvim Tree
keymap.set("n", "<leader>e", "<CMD>Neotree toggle<CR>", { desc = "Toggle Nvim Tree" })
keymap.set("n", "<leader>b", "<CMD>Neotree focus<CR>", { desc = "Focus Nvim Tree" })
-- keymap.set("n", "<leader>e", ":Neotree source=filesystem reveal=true position=right<cr>");

--Telescope
-- keymap.set("n", "<C-e>", "<cmd>Telescope find_files<cr>");
keymap.set("n", "<leader>ff", "<cmd>Telescope resume<cr>", { desc = "Telescope Resume last telescope" })
keymap.set("n", "<leader><space>", "<cmd>Telescope find_files theme=dropdown<cr>", { desc = "Telescope Find files" })
keymap.set("n", "<leader>fa", "<cmd>Telescope find_files hidden=true<cr>", { desc = "TelescopeFind hidden files" })
keymap.set(
	"n",
	"<leader>aa",
	"<cmd>Telescope find_files hidden=true theme=dropdown<cr>",
	{ desc = "TelescopeFind hidden files" }
)
keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep<cr>", { desc = "Telescope Live grep" })
keymap.set(
	"n",
	"<leader>F",
	"<cmd>lua require('grug-far').open({ prefills = { search = vim.fn.expand('<cword>') }})<cr>",
	{ desc = "GrugFar Live grep" }
)
keymap.set("n", "<leader>fc", "<cmd>Telescope live_grep hidden=true<cr>", { desc = "Telescope Live grep hidden" })
keymap.set("n", "<leader>km", "<cmd>Telescope keymaps<cr>", { desc = "Telescope Keymaps" })
-- keymap.set("v", "<leader>fs", "<cmd>Telescope grep_string<cr>", { desc = "Telescope Grep string" })
keymap.set(
	"v",
	"<leader>fs",
	"<cmd>lua require('grug-far').with_visual_selection()<cr>",
	{ desc = "Telescope Grep string" }
)
keymap.set("n", "?", "<cmd>Telescope live_grep<cr>", { desc = "Telescope Live grep" })
keymap.set("v", "<leader>fc", "<cmd>Telescope grep_string hidden=true<cr>", { desc = "Telescope Grep string hidden" })
keymap.set("n", "<leader>fh", "<cmd>DiffviewToggleFiles %<cr>", { desc = "Telescope Help tags" })
keymap.set("n", "<C-e>", "<cmd>Telescope buffers<cr>", { desc = "Telescope Buffers" })

--Format
api.nvim_set_keymap("n", "<leader>i", "<ESC><cmd>lua vim.lsp.buf.format({ timeout_ms = 2000 })<CR>", { noremap = true })
-- keymap.set("n", "<leader>nf", "<cmd>lua require('conform').format()<CR>", { desc = "Format" })
-- api.nvim_set_keymap("v", "<leader>nf", "<ESC><cmd>lua vim.lsp.buf.range_formatting()<CR>", { noremap = true })

--Gitsigns
keymap.set("n", "<leader>gn", "<cmd>Gitsigns next_hunk<cr>", { desc = "Gitsigns - Goto next hunk" })
keymap.set("n", "<leader>gp", "<cmd>Gitsigns prev_hunk<cr>", { desc = "Gitsigns - Goto previous hunk" })
keymap.set("n", "<leader>ph", "<CMD>Gitsigns preview_hunk<CR>", { desc = "Gitsigns - Preview hunk" })

-- Translate
keymap.set("n", "<leader>t", "<Cmd>Translate EN<CR>", { desc = "Translate" })

keymap.set("n", "<leader>rr", "<CMD>%bd|e#<CR>", { desc = "Close all buffer but current" })

-- Oils
keymap.set("n", "`", "<CMD>Oil --float<CR>", { desc = "Open oil" })

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
keymap.set("n", "<leader>op", "<cmd>Lspsaga outline<CR>", opts) -- see outline on right hand side

keymap.set("n", "<leader>F", "<cmd>GrugFar<CR>", { desc = "Find and replace" })

-- AI / Copilot Chat
