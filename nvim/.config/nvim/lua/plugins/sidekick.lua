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
  },
}
