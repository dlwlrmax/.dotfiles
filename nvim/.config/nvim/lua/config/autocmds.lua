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
    callback = function ()
        vim.lsp.start({
            name = "laravel-ls",

            -- if laravel ls is in your $PATH
            cmd = { 'laravel-ls' },

            -- Absolute path
            -- cmd = { '/path/to/laravel-ls/build/laravel-ls' },

            -- if you want to recompile everytime
            -- the language server is started.
            -- cmd = { '/path/to/laravel-ls/start.sh' },

            root_dir = vim.fn.getcwd(),
        })
    end
})

-- vim.lsp.config("laravel_ls", {
--   cmd = { "laravel-ls" },
--   filetypes = { "php", "blade" },
--   root_markers = { "artisan" },
-- })
