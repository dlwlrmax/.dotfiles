if true then return {} end
return {
  "folke/sidekick.nvim",
  opts = {
    cli = {
      ---@class sidekick.cli.Mux
      ---@field backend? "tmux"|"zellij" Multiplexer backend to persist CLI sessions
      mux = {
        backend = "tmux",
        enabled = true,
      },
    },
    signs = {
      enalbled = false,
    },
    copilot = {
      status = {
        enabled = true,
      },
    },
  },
}
