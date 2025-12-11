return {
  "Exafunction/codeium.nvim",
  opts = function(_, opts)
    opts.virtual_text.enabled = true
    opts.enable_cmp_source = false
    opts.virtual_text.key_bindings = {
      accept = "<M-l>",
      next = "<M-]>",
      prev = "<M-[>"
    }
  end,
}
