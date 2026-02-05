return {
  -- {
  --   "NickvanDyke/opencode.nvim",
  --   dependencies = {
  --     -- Recommended for `ask()` and `select()`.
  --     -- Required for `snacks` provider.
  --     ---@module 'snacks' <- Loads `snacks.nvim` types for configuration intellisense.
  --     { "folke/snacks.nvim", opts = { input = {}, picker = {}, terminal = {} } },
  --   },
  --   keys = {
  --     {
  --       "<C-p>",
  --       function()
  --         require("opencode").select()
  --       end,
  --       mode = { "n", "x" },
  --       desc = "Execute opencode action…",
  --     },
  --     {
  --       "<Leader>as",
  --       function()
  --         require("opencode").ask("@this: ", { submit = true })
  --       end,
  --       mode = { "n", "x" },
  --       desc = "Ask opencode…",
  --     },
  --     {
  --       "<Leader>aa",
  --       function()
  --         require("opencode").toggle()
  --       end,
  --       mode = { "n", "t" },
  --       desc = "Toggle opencode",
  --     },
  --     {
  --       "<leader>av",
  --       function()
  --         return require("opencode").operator("@this ")
  --       end,
  --       mode = { "n", "x" },
  --       desc = "Add range to opencode",
  --       expr = true,
  --     },
  --     {
  --       "<leader>at",
  --       function()
  --         return require("opencode").operator("@this ") .. "_"
  --       end,
  --       mode = { "n" },
  --       desc = "Add line to opencode",
  --       expr = true,
  --     },
  --   },
  --   config = function()
  --     ---@type opencode.Opts
  --     vim.g.opencode_opts = {
  --       -- Your configuration, if any — see `lua/opencode/config.lua`, or "goto definition" on the type or field.
  --       provider = {
  --         enabled = "snacks",
  --       },
  --     }
  --
  --     -- Required for `opts.events.reload`.
  --     vim.o.autoread = true
  --   end,
  -- },
  {
    "folke/sidekick.nvim",
    opts = function(_, opts)
      local setting = {
        nes = {
          enabled = false,
        },
        copilot = {
          status = {
            enabled = false,
          },
        },
        cli = {
          mux = {
            enabled = true,
            backend = "tmux",
          },
          tools = {
            opencode = {
              cmd = { "opencode" },
              -- HACK: https://github.com/sst/opencode/issues/445
              env = { OPENCODE_THEME = "catppuccin" },
            },
            qwen = { cmd = { "qwen" } },
          },
          prompts = {
            refactor = "Please refactor {this} to be more maintainable",
            security = "Review {file} for security vulnerabilities",
            custom = function(ctx)
              return "Current file: " .. ctx.buf .. " at line " .. ctx.row
            end,
          },
        },
      }
      return vim.tbl_deep_extend("force", opts, setting)
    end,
    keys = {
      {
        "<leader>aa",
        function()
          -- require("sidekick.cli").toggle({ name = "qwen", focus = true })
          require("sidekick.cli").toggle({ name = "opencode", focus = true })
        end,
        desc = "Sidekick Toggle CLI - Opencode",
      },
    },
  },
}
