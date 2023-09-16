require('catppuccin').setup({
    flavour = "mocha", -- latte, frappe, macchiato, mocha
    background = {         -- :h background
      light = "latte",
      dark = "macchiato",
    },
    transparent_background = true,
    term_colors = true,
    dim_inactive = {
      enabled = false,
      shade = "dark",
      percentage = 0.15,
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
    integrations = {
      cmp = true,
      gitsigns = true,
      neotree = true,
      neogit = true,
      telescope = true,
      native_lsp = {
        enable = true,
        virtual_text = {
          errors = { "italic" },
          hints = { "italic" },
          warning = { "italic" },
          infomation = { "italic" },
        },
        underlines = {
          errors = { "italic" },
          hints = { "italic" },
          warning = { "italic" },
          infomation = { "italic" },
        },
        inlay_hints = {
          background = true,
        },
      },
      lsp_saga = true,
      which_key = true,
      indent_blankline = {
        enabled = true,
        colored_indent_levels = false,
      },
      mason = true,
      treesitter_context = true,
      notify = true,
      noice = true,
      mini = true,
      barbar = true,
      barbecue = {
        dim_dirname = true,
        bold_basename = true,
        dim_context = false,
        alt_background = false,
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
  
