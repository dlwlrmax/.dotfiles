-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Close Diffview before Neovim exits
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    local success, _ = pcall(vim.cmd, "DiffviewClose")
    if success then
      vim.notify("Diffview closed before exit", vim.log.levels.INFO)
    end
  end,
})

-- handle Hlargs Lsp semantic tokens
vim.api.nvim_create_augroup("LspAttach_hlargs", { clear = true })
vim.api.nvim_create_autocmd("LspAttach", {
  group = "LspAttach_hlargs",
  callback = function(args)
    if not (args.data and args.data.client_id) then
      return
    end
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then
      return
    end
    local caps = client.server_capabilities
    if not caps then
      return
    end
    if caps.semanticTokensProvider and caps.semanticTokensProvider.full then
      require("hlargs").disable_buf(args.buf)
    end
  end,
})
