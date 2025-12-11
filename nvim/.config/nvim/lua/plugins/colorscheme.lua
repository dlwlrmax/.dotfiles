return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
  },
  {
    "catppuccin/nvim",
    lazy = false,
    priority = 1000,
    opts = {
      term_colors = true,
      custom_highlights = function(colors)
        return {
          LineNr = { fg = colors.overlay0 },
          NeoTreeDotfile = { fg = colors.overlay0 },
          NeoTreeMessage = { fg = colors.surface2 },
          SnacksPickerListCursorLine = { bg = "#223547" },
          SnacksPickerSelected = { fg = colors.lavender },
          WinSeparator = { fg = colors.pink, bold = true },
          VertSplit = { fg = colors.pink, bold = true },
          CodeiumSuggestion = { fg = colors.overlay0 },
        }
      end,
      auto_integrations = true,
    },
  },
}
