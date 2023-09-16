local opt = vim.opt
local g = vim.g
local prefix = vim.env.XDG_CONFIG_HOME or vim.fn.expand("~/.config")
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
opt.undodir = { prefix .. "/nvim/.undo//"}
opt.backupdir = {prefix .. "/nvim/.backup//"}
opt.directory = { prefix .. "/nvim/.swp//"}
opt.backup = false
opt.swapfile = false
opt.updatetime = 200

opt.relativenumber = true
opt.number = true
opt.guifont = { "JetBrainsMono Nerd Font", ":h14"}

opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.autoindent = true

opt.wrap = false

opt.ignorecase = true
opt.smartcase = true

opt.termguicolors = true
opt.signcolumn = "yes"

opt.backspace = "indent,eol,start"

opt.clipboard:append("unnamedplus")

opt.splitright = true
opt.splitbelow = true

-- opt.iskeyword:append("-")
-- opt.iskeyword:append("/")
opt.encoding = "utf-8"
opt.showmatch = true

-- Startify config

g.startify_custom_header = {
'',
'',
'                                       ██            ',
'                                      ░░             ',
'    ███████   █████   ██████  ██    ██ ██ ██████████ ',
'   ░░██░░░██ ██░░░██ ██░░░░██░██   ░██░██░░██░░██░░██',
'    ░██  ░██░███████░██   ░██░░██ ░██ ░██ ░██ ░██ ░██',
'    ░██  ░██░██░░░░ ░██   ░██ ░░████  ░██ ░██ ░██ ░██',
'    ███  ░██░░██████░░██████   ░░██   ░██ ███ ░██ ░██',
'   ░░░   ░░  ░░░░░░  ░░░░░░     ░░    ░░ ░░░  ░░  ░░ ',
'',
'',
}
g.webdevicons_enable_startify = 1
g.startify_enable_special = 0
g.startify_session_autoload = 1
g.startify_session_delete_buffers = 1
g.startify_change_to_vcs_root = 1
g.startify_fortune_use_unicode = 1
g.startify_session_persistence = 1
g.startify_lists = {
  { type = 'sessions', header = { "   Sessions "..vim.fn.getcwd()..":" } },
  { type = 'dir', header = { "   Current Directory "..vim.fn.getcwd()..":" } },
  { type = 'bookmarks', header = { '   Bookmarks' } }
}

g.indent_blankline_filetype_exclude = {'help', 'startify'};
g.loaded_netrw = 1
g.loaded_netrwPlugin = 1

-- Config popup border 
vim.diagnostic.config {
  float = {
    border = "rounded"
  }
}

vim.o.foldcolumn = '1'
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldenable = true

vim.o.scrolloff = 5
-- -- Disable virtual_text since it's redundant due to lsp_lines.
-- vim.diagnostic.config({
--   virtual_text = false,
-- })
