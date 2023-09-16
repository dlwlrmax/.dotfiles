local setup, lualine = pcall(require, "lualine")

if not setup then
  return
end

lualine.setup({
  options = {
    theme = "catppuccin",
    component_separators = '|',
  },
  sections = {
    lualine_a = {
      { 'mode', right_padding = 3 },
    },
    lualine_b = { 'branch', 'diff', 'diagnostics' },
    lualine_c = { { 'filename', file_status = false, path = 1 } },
    lualine_x = { 'encoding', 'fileformat', 'filetype', 'tabnine' },
    lualine_y = { 'tabnine' },
    lualine_z = {
      { 'location', left_padding = 2 },
    },
  },
  inactive_sections = {
    lualine_a = { 'filename' },
    lualine_b = {},
    lualine_c = {},
    lualine_x = {},
    lualine_y = {},
    lualine_z = { 'location' },
  },
  tabline = {},
  extensions = {},
})