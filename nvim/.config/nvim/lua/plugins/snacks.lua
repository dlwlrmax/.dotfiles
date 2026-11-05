return {
  "folke/snacks.nvim",
  keys = {
    {
      "<leader>bb",
      function()
        Snacks.picker.buffers()
      end,
      desc = "Buffers",
    },
    {
      "<C-e>",
      function()
        Snacks.picker.buffers()
      end,
      desc = "Buffers",
    },
  },
  opts = {
    picker = {
      sources = {
        explorer = {
          auto_close = false,
          hidden = true,
          ignored = false,
        },
        files = {
          hidden = false,
          ignored = false,
          follow = true,
          exclude = { "node_modules", ".undo" },
        },
      },
      matcher = {
        frecency = true,
        cwd_bonus = true,
      },
      formatters = {
        file = {
          filename_first = true,
          truncate = 120,
        },
      },
    },

    indent = {
      chunk = { enabled = true, only_current = true },
    },

    dashboard = {
      enabled = true,
      sections = {
        {
          section = "header",
        },
        { icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
        { icon = " ", title = "Keymaps", section = "keys", indent = 2, padding = 1 },
        { icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
        {
          icon = " ",
          title = "Git Status",
          section = "terminal",
          enabled = function()
            return Snacks.git.get_root() ~= nil
          end,
          cmd = "git status --short --branch --renames",
          height = 5,
          padding = 1,
          ttl = 5 * 60,
          indent = 3,
        },
        { section = "startup" },
      },
    },
    words = { enabled = true },
  },
}
