local mason_status, mason = pcall(require, "mason")
if not mason_status then
  return
end

local mason_lsp_status, mason_lsp = pcall(require, "mason-lspconfig")
if not mason_lsp_status then
  return
end

local null_ls_status, null_ls = pcall(require, "null-ls")
if not null_ls_status then
  return
end

mason.setup()

mason_lsp.setup({
  ensure_installed = {
    "tsserver",
    "html",
    "cssls",
    -- "tailwindcss",
    "lua_ls",
    "phpactor",
  }
})

null_ls.setup({
  ensure_installed = {
    "prettier",
    "stylelua"
  }
})
