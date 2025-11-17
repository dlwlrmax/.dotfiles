return {
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
        win = {
          split = {
            width = 90,
            height = 20,
          },
        },
        tools = {
          opencode = {
            cmd = { "opencode" },
            -- HACK: https://github.com/sst/opencode/issues/445
            env = { OPENCODE_THEME = "system" },
          },
          qwen = { cmd = { "qwen" } },
          gemini = { cmd = { "gemini" } },
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
        require("sidekick.cli").toggle({ filter = { installed = true } })
      end,
      desc = "Sidekick Toggle CLI",
    },
    {
      "<leader>ac",
      function()
        require("sidekick.cli").toggle({ name = "opencode", focus = true })
      end,
      desc = "Sidekick Toggle CLI - Opencode",
    }
  },
}
