local indent_blankline_status, indent_blankline = pcall(require, "ibl")
if not indent_blankline_status then
  return
end

vim.opt.list = true
vim.opt.listchars:append "space:⋅"
vim.opt.listchars:append "tab:|⇢"
vim.opt.listchars:append "trail:·"

indent_blankline.setup {
}
