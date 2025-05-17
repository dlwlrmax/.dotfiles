local vim = vim or require("vim")
local opt = vim.opt
local g = vim.g
local prefix = vim.env.XDG_CONFIG_HOME or vim.fn.expand("~/.config")
vim.o.termguicolors = true
vim.g.loaded_netrwPlugin = 1
vim.g.editorconfig = true
opt.undodir = { prefix .. "/nvim/.undo//" }
opt.backupdir = { prefix .. "/nvim/.backup//" }
opt.directory = { prefix .. "/nvim/.swp//" }
opt.backup = false
opt.swapfile = false
opt.updatetime = 200
opt.cursorline = true
opt.undofile = true

opt.guifont = { "JetBrainsMono Nerd Font", ":h14" }

opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.smartindent = true
opt.autoindent = true

opt.wrap = false
opt.linebreak = true

opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.inccommand = "split"

opt.termguicolors = true
opt.signcolumn = "yes"

opt.backspace = { "indent", "eol", "start" }
opt.clipboard:append("unnamedplus")

opt.splitright = true
opt.splitbelow = true

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

-- NOTE: This is a workaround for the issue where the indent guides too bright and distracting.
vim.api.nvim_set_hl(0, "SnacksIndent", { fg = "#4c4f69", bg = "NONE" })
-- vim.api.nvim_set_hl(0, "SnacksIndentChunk", { fg = "#8839ef", bg = "NONE", bold = true })
