return {
  "nvim-lualine/lualine.nvim",
  -- Tweak LazyVim's defaults in place (keeps extras' components, e.g. sidekick).
  opts = function(_, opts)
    local icons = LazyVim.config.icons
    -- plain filename instead of pretty_path
    opts.sections.lualine_c = {
      LazyVim.lualine.root_dir(),
      { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
      { "filename" },
      {
        "diagnostics",
        symbols = {
          error = icons.diagnostics.Error,
          warn = icons.diagnostics.Warn,
          info = icons.diagnostics.Info,
          hint = icons.diagnostics.Hint,
        },
      },
    }
    -- no clock
    opts.sections.lualine_z = nil
  end,
}
