local setup, wk = pcall(require, "which-key")

if not setup then 
  return 
end 

wk.setup {
   icons = {
    breadcrumb = "»", -- symbol used in the command line area that shows your active key combo
    separator = "➜", -- symbol used between a key and it's label
    group = "+", -- symbol prepended to a group
  },
  disabled = {
    bufftype = {},
    filetype = { "TelescopePrompt" },
  },
  triggers = "auto",
  triggers_blacklist = {
    i = { "j", "k" },
    v = { "j", "k" },
  },
  show_help = true,
  show_keys = true,
  ignore_missing = false,
  layout = {
    height = { min = 4, max = 25 },
    width = { min = 20, max = 50 },
    spacing = 3,
    align = "center"
  },
  window = {
    border = "single",
    position = "bottom",
    margin = { 1, 1, 1, 1 },
    padding = { 2, 2, 2, 2 },
    winblend = 0
  },
  presets = {
    operators = true,
    motions = true,
    text_objects = true,
    z = true,
    g = true
  }
}

wk.register(mappings, opts);
