return ({
  "neovim/nvim-lspconfig",
  opts = function(_, opts)
    opts.servers.vtsls.settings.vtsls.experimental = vim.tbl_deep_extend("force", opts.servers.vtsls.settings.vtsls.experimental or {}, { maxInlayHintLength = 10 })
  end,
})
