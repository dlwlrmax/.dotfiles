return {
  "sindrets/diffview.nvim",
  cmd = {
    "DiffviewOpen",
    "DiffviewClose",
    "DiffviewToggleFiles",
    "DiffviewFocusFiles",
    "DiffviewFileHistory",
  },
  keys = {
    { "<leader>do", "<cmd>DiffviewOpen<cr>", desc = "[Diffview] Open" },
    { "<leader>dq", "<cmd>DiffviewClose<cr>", desc = "[Diffview] Close" },
    { "<leader>df", "<cmd>DiffviewFileHistory %<cr>", desc = "[Diffview] File History", mode = { "n" } },
    { "<leader>df", ":DiffviewFileHistory<cr>", desc = "[Diffview] File History", mode = { "v" } },
  },
  opts = {
    diff_binaries = false,
    use_icons = true,
    icon_set = "default",
    signs = {
      fold_closed = "",
      fold_open = "",
    },
  },
}
