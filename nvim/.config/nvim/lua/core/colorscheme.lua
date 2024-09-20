require('catppuccin').setup({
  flavour = "mocha",   -- latte, frappe, macchiato, mocha
  background = {           -- :h background
    light = "mocha",
    dark = "latte",
  },
  transparent_background = false,
  term_colors = false,
  dim_inactive = {
    enabled = true,
    shade = "dark",
    percentage = 0.2,
  },
  styles = {
    comments = { "italic" },
    conditionals = { "bold" },
    loops = { "bold" },
    functions = { "italic", "bold" },
    keywords = { "italic" },
    booleans = { "bold" },
    operators = {},
    strings = {},
    variables = {},
    numbers = {},
    properties = {},
    types = { "bold" },
  },
  compile_path = vim.fn.stdpath("cache") .. "/catppuccin",
  default_integrations = true,
  integrations = {
    cmp = true,
    gitsigns = true,
    neotree = true,
    neogit = true,
    telescope = true,
    native_lsp = {
      enable = true,
      virtual_text = {
        errors = { "italic", "bold" },
        hints = { "italic" },
        warning = { "italic" },
        information = { "italic" },
      },
      inlay_hints = {
        background = true,
      },
    },
    lsp_saga = {
      ui = {
        kind = require('catppuccin.groups.integrations.lsp_saga').custom_kind(),
      }
    },
    which_key = true,
    indent_blankline = {
      enabled = true,
      colored_indent_levels = true,
    },
    mason = true,
    treesitter_context = true,
    notify = true,
    mini = true,
    barbecue = {
      dim_context = true,
      alt_background = false,
      bold_basename = true,
      dim_dirname = true
    },
    beacon = true,
    harpoon = true,
    fidget = true,
    -- For more plugins integrations please scroll down (https://github.com/catppuccin/nvim#integrations)
  },
})

local status, _ = pcall(vim.cmd, "colorscheme catppuccin")
-- local status, _ = pcall(vim.cmd, "colorscheme dracula")
if not status then
  print("Colorscheme not found!")
  return
end
