-- import null-ls plugin safely
local setup, null_ls = pcall(require, "null-ls")
if not setup then
  return
end

local mason_status, mason = pcall(require, "mason")
if not mason_status then
  return
end

local mason_null_status, mason_null = pcall(require, "mason-null-ls")
if not setup then
  return
end

-- for conciseness
local formatting = null_ls.builtins.formatting   -- to setup formatters
local diagnostics = null_ls.builtins.diagnostics -- to setup linters
local code_actions = null_ls.builtins.code_actions

-- to setup format on save
local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
mason.setup()
-- configure null_ls
null_ls.setup({
  -- setup formatters & linters
  sources = {
    --  to disable file types use
    --  "formatting.prettier.with({disabled_filetypes: {}})" (see null-ls docs)
    formatting.prettierd.with({
      filetypes = { "javascript", "scss", "css", "typescript", "json", "html", "vue" },
    }), -- js/ts formatter
    formatting.phpcsfixer,
    formatting.stylua.with({
      filetypes = { "lua" }
    }), -- lua formatter
    -- format blade
    formatting.blade_formatter.with({
      filetypes = { "blade" },
    }),
    code_actions.eslint_d,
    -- code_actions.gitsigns,
    diagnostics.cspell,
    diagnostics.eslint_d.with({                    -- js/ts lintek
      condition = function(utils)
        return utils.root_has_file(".eslintrc.js") -- change file extension if you use something else
      end,
    }),
  },
  -- configure format on save
  on_attach = function(current_client, bufnr)
    if current_client.name == 'tsserver' then
      current_client.resolved_capabilities.document_formatting = false
    end
    if current_client.supports_method("textDocument/formatting") then
      vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = augroup,
        buffer = bufnr,
        callback = function()
          vim.lsp.buf.format({
            filter = function(client)
              --  only use null-ls for formatting instead of lsp server
              return client.name == "null-ls"
            end,
            bufnr = bufnr,
          })
        end,
      })
    end
  end,
})

-- mason_null.setup()
