return {
  "ThePrimeagen/harpoon",
  -- LazyVim's `editor.harpoon2` extra already supplies branch = "harpoon2",
  -- opts.settings.save_on_toggle, the <leader>h quick menu and <leader>1-9
  -- selects. This spec only overrides the add key and drops the extra's
  -- duplicate <leader>H.
  keys = {
    {
      "<leader>ah",
      function()
        require("harpoon"):list():add()
      end,
      desc = "Harpoon File",
    },
    { "<leader>H", false },
  },
}
