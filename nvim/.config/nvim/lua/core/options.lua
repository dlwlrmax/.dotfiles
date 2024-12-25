local opt = vim.opt
local g = vim.g
local prefix = vim.env.XDG_CONFIG_HOME or vim.fn.expand("~/.config")
vim.o.termguicolors = true
vim.g.loaded_netrwPlugin = 1
opt.undodir = { prefix .. "/nvim/.undo//" }
opt.backupdir = { prefix .. "/nvim/.backup//" }
opt.directory = { prefix .. "/nvim/.swp//" }
opt.backup = false
opt.swapfile = false
opt.updatetime = 200
opt.cursorline = true

opt.guifont = { "JetBrainsMono Nerd Font", ":h14" }

opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.autoindent = true

opt.wrap = true

opt.ignorecase = true
opt.smartcase = true

opt.termguicolors = true
opt.signcolumn = "yes"

opt.backspace = "indent,eol,start"

opt.clipboard = "unnamedplus"

opt.splitright = true
opt.splitbelow = true

-- opt.iskeyword:append("-")
-- opt.iskeyword:append("/")
opt.encoding = "utf-8"
opt.showmatch = true

g.indent_blankline_filetype_exclude = { "help", "startify" }
g.loaded_netrwPlugin = 1

-- Config popup border
vim.diagnostic.config({
	float = {
		border = "rounded",
	},
})

vim.o.scrolloff = 20
vim.o.sidescrolloff = 20
-- -- Disable virtual_text since it's redundant due to lsp_lines.
-- vim.diagnostic.config({
--   virtual_text = false,
-- })

opt.relativenumber = true
opt.number = true
vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"
vim.o.laststatus = 3
