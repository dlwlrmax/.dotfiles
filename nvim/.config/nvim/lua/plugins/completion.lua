return {
  {
    "monkoose/neocodeium",
    event = "VeryLazy",
    keys = {
      {
        "<M-l>",
        function()
          require("neocodeium").accept()
        end,
        mode = { "i" },
        desc = "[Neocodeium] Complete",
      },
      {
        "<M-]>",
        function()
          require("neocodeium").cycle(1)
        end,
        mode = { "i" },
        desc = "[Neocodeium] Next Completion",
      },
      {
        "<M-[>",
        function()
          require("neocodeium").cycle(-1)
        end,
        mode = { "i" },
        desc = "[Neocodeium] Previous Completion",
      },
      {
        "<A-w>",
        function()
          require("neocodeium").accept_word()
        end,
        mode = { "i" },
        desc = "[Neocodeium] Accept Word",
      }
    },
    config = function()
      local neocodeium = require("neocodeium")
      neocodeium.setup()
    end,
  },
}
