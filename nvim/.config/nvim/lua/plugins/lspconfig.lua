return {
  "neovim/nvim-lspconfig",
  opts = function(_, opts)
    opts.servers["*"].capabilities = vim.tbl_deep_extend(
      "force",
      opts.servers["*"].capabilities or {},
      require("blink.cmp").get_lsp_capabilities()
    )
    opts.servers.vtsls.settings.vtsls.experimental =
      vim.tbl_deep_extend("force", opts.servers.vtsls.settings.vtsls.experimental or {}, { maxInlayHintLength = 10 })
    opts.servers.intelephense = vim.tbl_deep_extend(
      "force",
      opts.servers.intelephense or {},
      {
        settings = { intelephense = { files = { maxSize = 1000000 } } },
        init_options = { licenceKey = vim.fn.expand("$HOME/intelephense/licence.txt") },
      }
    )
  end,
}
