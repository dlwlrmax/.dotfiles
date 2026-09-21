return {
  "neovim/nvim-lspconfig",
  opts = function(_, opts)
    opts.servers["*"].capabilities =
      vim.tbl_deep_extend("force", opts.servers["*"].capabilities or {}, require("blink.cmp").get_lsp_capabilities())
    opts.servers.vtsls = opts.servers.vtsls or {}
    opts.servers.vtsls.settings = vim.tbl_deep_extend("force", opts.servers.vtsls.settings or {}, {
      vtsls = { experimental = { maxInlayHintLength = 10 } },
    })
    opts.servers.intelephense = vim.tbl_deep_extend("force", opts.servers.intelephense or {}, {
      settings = { intelephense = { files = { maxSize = 1000000 } } },
      init_options = { licenceKey = vim.fn.expand("$HOME/intelephense/licence.txt") },
    })
  end,
}
