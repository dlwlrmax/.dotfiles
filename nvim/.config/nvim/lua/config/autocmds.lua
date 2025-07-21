-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Enabled Laravel-ls
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "php", "blade" },
  callback = function()
    local root_dir = vim.fs.find("composer.json", { upward = true, stop = vim.loop.os_homedir() })[1]
    if root_dir then
      root_dir = vim.fn.fnamemodify(root_dir, ":h") -- Get the directory containing composer.json
      vim.lsp.start({
        name = "laravel-ls",
        cmd = { "laravel-ls" },
        root_dir = root_dir,
      })
    end
  end,
})
