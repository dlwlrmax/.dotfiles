return {
  "gitsigns.nvim",
  opts = {
    current_line_blame = true,
    current_line_blame_opts = {
      delay = 500, -- debounce blame: avoid work on every cursor move
      virtual_text = false, -- cheaper than virtual text on every line
    },
    attach_to_untracked = true,
  },
}
