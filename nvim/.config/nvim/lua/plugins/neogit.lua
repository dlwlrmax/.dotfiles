return {
  "NeogitOrg/neogit",
  dependencies = {
    "nvim-lua/plenary.nvim",         -- required
    "sindrets/diffview.nvim",        -- optional - Diff integration

    -- Only one of these is needed.
    "nvim-telescope/telescope.nvim", -- optional
    "ibhagwan/fzf-lua",              -- optional
    "echasnovski/mini.pick",         -- optional
  },
  config = function()
    require("neogit").setup {
      integrations = {
        diffview = true,
        telescope = true,
        fzf = true,
        mini = true,
      },
    }
    vim.api.nvim_set_keymap('n', '<leader>gg', '<ESC><cmd>Neogit<CR>', {noremap = true})
  end,
}

