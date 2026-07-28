return {
  "windwp/nvim-ts-autotag",
  event = "InsertEnter",
  opts = {
    per_filetype = {
      ["php"] = {
        enable_close = false,
      },
    },
  },
}
