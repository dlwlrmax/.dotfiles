return {
  "echasnovski/mini.files",
  keys = {
    {
      "-",
      function()
        require("mini.files").open(vim.api.nvim_buf_get_name(0), true)
      end,
      mode = { "n" },
      desc = "Open mini.files (Directory of Current File)",
    },
  },
}
