return {
  "nvim-mini/mini.files",
  keys = {
    {
      "-",
      function()
        local name = vim.api.nvim_buf_get_name(0)
        require("mini.files").open(name ~= "" and name or vim.uv.cwd(), true)
      end,
      mode = { "n" },
      desc = "Open mini.files (Directory of Current File)",
    },
    {
      "_",
      function()
        require("mini.files").open(vim.fn.getcwd(), true)
      end,
      mode = { "n" },
      desc = "Open mini.files (Current Working Directory)",
    },
  },
  opts = {
    mappings = {
      close = "q",
      go_in = "",
      go_in_plus = "L",
      go_out = "",
      go_out_plus = "H",
      mark_goto = "'",
      mark_set = "m",
      reset = "<BS>",
      reveal_cwd = "@",
      show_help = "g?",
      synchronize = "<CR>",
      trim_left = "<",
      trim_right = ">",
    },
  },
}
