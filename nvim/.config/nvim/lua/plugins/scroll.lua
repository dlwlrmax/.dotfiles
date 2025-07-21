return {
  "petertriho/nvim-scrollbar",
  event = "BufRead",
  lazy = true,
  config = function()
    require("scrollbar").setup()
  end,
}
