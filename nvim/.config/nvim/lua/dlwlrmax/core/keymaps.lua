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
keymap.set("n", "<A-q>", "<Cmd>wq!<CR>")
-- keymap.set("n", "<leader>bd", ":BClose<cr>:tabclose<cr>gT");
-- bufferline
keymap.set("n", "<leader>h", "<Cmd>BufferPrevious<CR>")
keymap.set("n", "<leader>l", "<Cmd>BufferNext<CR>")
keymap.set("n", "<leader>p", "<Cmd>BufferPin<CR>")
keymap.set("n", "<leader>ml", "<Cmd>BufferMoveNext<CR>")
keymap.set("n", "<leader>mh", "<Cmd>BufferMovePrevious<CR>")
keymap.set("n", "<A-1>", "<Cmd>BufferGoto 1<CR>")
keymap.set("n", "<A-2>", "<Cmd>BufferGoto 2<CR>")
keymap.set("n", "<A-3>", "<Cmd>BufferGoto 3<CR>")
keymap.set("n", "<A-4>", "<Cmd>BufferGoto 4<CR>")
keymap.set("n", "<A-5>", "<Cmd>BufferGoto 5<CR>")
keymap.set("n", "<A-6>", "<Cmd>BufferGoto 6<CR>")
keymap.set("n", "<A-7>", "<Cmd>BufferGoto 7<CR>")
keymap.set("n", "<A-8>", "<Cmd>BufferGoto 8<CR>")
keymap.set("n", "<A-9>", "<Cmd>BufferGoto 9<CR>")
keymap.set("n", "<A-0>", "<Cmd>BufferGoto 0<CR>")
keymap.set("n", "<C-w>", "<Cmd>BufferClose<CR>")
keymap.set("n", "<Leader>rt", "<Cmd>BufferRestore<CR>")
keymap.set("n", "<leader>q", "<Cmd>b#<CR>")

-- Replace

keymap.set("n", "<leader>rp", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

--Nvim Tree
keymap.set("n", "<leader>e", "<CMD>Neotree toggle<CR>")
keymap.set("n", "<leader>b", "<CMD>Neotree focus<CR>")
-- keymap.set("n", "<leader>e", ":Neotree source=filesystem reveal=true position=right<cr>");

--Telescope
-- keymap.set("n", "<C-e>", "<cmd>Telescope find_files<cr>");
keymap.set("n", "<leader>ff", "<cmd>Telescope find_files theme=dropdown<cr>")
keymap.set("n", "<leader>fs", "<cmd>FzfxLiveGrepW<cr>")
keymap.set("n", "<leader><space>", "<cmd>FzfxFiles<cr>")
keymap.set("n", "?", "<cmd>Telescope live_grep theme=dropdown<cr>")
keymap.set("n", "<leader>fc", "<cmd>Telescope grep_string<cr>")
keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>")
keymap.set("n", "<leader>fh", "<cmd>Telescope help_tags<cr>")
keymap.set("n", "<leader>tr", "<CMD>Telescope resume<CR>")

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

-- Translate
keymap.set("n", "<leader>t", "<Cmd>Translate EN<CR>")

-- back to home page
keymap.set("n", "<leader>gh", "<CMD>Startify<CR>")

keymap.set("n", "<leader>gf", "<CMD>SymbolsOutline<CR>")

keymap.set("n", "<leader>bo", "<CMD>%bd|e#|bd#<CR>", { desc = "Close all buffer but current" })
keymap.set("n", "<leader>rr", "<CMD>%bd|e#|bd#<CR>", { desc = "Close all buffer but current" })
-- keymap.set("n", "<leader>rr", ":so ~/.config/nvim/init.lua<cr>")
