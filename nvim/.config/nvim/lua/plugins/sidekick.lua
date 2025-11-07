return {
  "folke/sidekick.nvim",
  opts = {
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
  },
  keys = {
    {
      "<leader>aa",
      function()
        require("sidekick.cli").toggle({ filter = { installed = true } })
      end,
      desc = "Sidekick Toggle CLI",
    },
  },
}
