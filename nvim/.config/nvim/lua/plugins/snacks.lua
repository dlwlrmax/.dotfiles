return {
  "folke/snacks.nvim",
  keys= {
    { "<leader>bb", function() Snacks.picker.buffers() end, desc = "Buffers" },
  },
  opts = {
    picker = {
      sources = {
        explorer = {
          auto_close = true,
          hidden = true,
          ignored = true,
        },
        files = {
          hidden = true,
          ignored = true,
          follow = true,
          exclude = { "node_modules", ".undo" },
        },
      },
    },
    indent = {
      enabled = true,
      indent = {
        priority = 1,
        enabled = true, -- enable indent guides
        char = "│",
        only_scope = false, -- only show indent guides of the scope
        only_current = false, -- only show indent guides in the current window
        hl = "SnacksIndent", ---@type string|string[] hl groups for indent guides
      },
      chunk = {
        enabled = true,
        only_current = true,
        priority = 200,
        hl = "SnacksIndentChunk", ---@type string|string[] hl group for chunk scopes
        char = {
          corner_top = "╭",
          corner_bottom = "╰",
          horizontal = "─",
          vertical = "│",
          arrow = "",
        },
      },
      filter = function(buf)
        return vim.g.snacks_indent ~= false and vim.b[buf].snacks_indent ~= false and vim.bo[buf].buftype == ""
      end,
    },
    statuscolumn = {
      left = { "mark", "sign" },
      right = { "fold", "git" },
      folds = {
        open = "false",
        git_hl = "false",
      },
      git = {
        pattern = { "GitSigns", "MiniDiffSign" },
      },
      refresh = 100,
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
          cmd = "hub status --short --branch --renames",
          height = 5,
          padding = 1,
          ttl = 5 * 60,
          indent = 3,
        },
        { section = "startup" },
      },
    },
  },
}
