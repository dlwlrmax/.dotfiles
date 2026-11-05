return {
  "folke/which-key.nvim",
  opts = function(_, opts)
    opts.spec = opts.spec or {}
    vim.list_extend(opts.spec, {
      { "<leader>a", group = "ai", mode = { "n", "v" } },
      -- diffview.lua lives here; LazyVim labels <leader>d "debug". If you add the
      -- dap.core extra, move diffview: <leader>do clashes with DAP "Step Out".
      { "<leader>d", group = "diffview" },
    })
  end,
}
