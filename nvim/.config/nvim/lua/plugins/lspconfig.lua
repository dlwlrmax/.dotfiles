local licence_key
do
  local ok, lines = pcall(vim.fn.readfile, vim.fn.expand("~/intelephense/licence.txt"))
  local first = ok and lines[1] or nil
  if first and vim.trim(first) ~= "" then
    licence_key = vim.trim(first)
  else
    vim.schedule(function()
      vim.notify("intelephense licence.txt not found, running unlicensed", vim.log.levels.WARN)
    end)
  end
end

return {
  "neovim/nvim-lspconfig",
  opts = function(_, opts)
    opts.servers.vtsls = opts.servers.vtsls or {}
    opts.servers.vtsls.settings = vim.tbl_deep_extend("force", opts.servers.vtsls.settings or {}, {
      vtsls = { experimental = { maxInlayHintLength = 10 } },
    })
    opts.servers.intelephense = vim.tbl_deep_extend("force", opts.servers.intelephense or {}, {
      settings = { intelephense = { files = { maxSize = 1000000 } } },
      init_options = { licenceKey = licence_key },
    })
  end,
}
