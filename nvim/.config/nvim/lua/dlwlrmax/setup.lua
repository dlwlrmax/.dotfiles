local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
-- Example using a list of specs with the default options
vim.g.mapleader = " " -- Make sure to set `mapleader` before lazy so your mappings are correct

local plugins = {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({ background = { dark = "macchiato" } })
      vim.cmd.colorscheme("catppuccin")
    end,
  },
  { "nvim-lua/plenary.nvim" },
  { "christoomey/vim-tmux-navigator" },
  {
    "numToStr/Comment.nvim",
    opts = {
      -- add any options here
    },
    lazy = false,
  },
  { "nvim-tree/nvim-web-devicons" },
  { "nvim-lualine/lualine.nvim",  event = "VeryLazy" },
  { "nvim-lua/popup.nvim" },
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      {
        "L3MON4D3/LuaSnip",
        dependencies = { "rafamadriz/friendly-snippets" },
        -- follow latest release.
        version = "2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
        -- install jsregexp (optional!).
        build = "make install_jsregexp",
        keys = function()
          return {}
        end,
      },
      "hrsh7th/cmp-emoji",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-nvim-lsp-document-symbol",
      "lukas-reineke/cmp-under-comparator",
    },
  },
  {
    "tzachar/cmp-tabnine",
    build = "./install.sh",
    dependencies = "hrsh7th/nvim-cmp",
  },
  { "saadparwaiz1/cmp_luasnip" },
  {
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
  },
  {
    "nvimtools/none-ls.nvim",
    dependencies = {
      "nvimtools/none-ls-extras.nvim",
      "gbprod/none-ls-php.nvim",
    },
    event = { "BufReadPre", "BufNewFile" },
  },
  { "lukas-reineke/indent-blankline.nvim", main = "ibl", opts = {} },
  {
    "nvimdev/lspsaga.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter", -- optional
      "nvim-tree/nvim-web-devicons",  -- optional
      "nvim-treesitter/nvim-treesitter-textobjects",
      "nvim-treesitter/nvim-treesitter-context",
    },
  },
  { "windwp/nvim-ts-autotag" },
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {
      check_ts = true,
      ts_config = {
        lua = { "string" }, -- it will not add pair on that treesitter node
        javascript = { "template_string" },
        java = false,   -- don't check treesitter on java
      },
    },                  -- this is equalent to setup({}) function
  },
  { "lewis6991/gitsigns.nvim" },
  { "jose-elias-alvarez/typescript.nvim" },
  { "onsails/lspkind.nvim" },
  { "mhinz/vim-startify" },
  { "m-demare/hlargs.nvim" },
  { "winston0410/cmd-parser.nvim" },
  { "ThePrimeagen/harpoon" },
  { "uga-rosa/translate.nvim" },
  { "kevinhwang91/nvim-ufo",             dependencies = { "kevinhwang91/promise-async" } },
  { "petertriho/nvim-scrollbar" },
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",      -- required
      "nvim-telescope/telescope.nvim", -- optional
      "sindrets/diffview.nvim",     -- optional
      "ibhagwan/fzf-lua",           -- optional
    },
    config = true,
  },
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    ---@type Flash.Config
    opts = {},
    -- stylelua : ignore
    keys = {
      {
        "s",
        mode = { "n", "x", "o" },
        function()
          require("flash").jump()
        end,
        desc = "Flash",
      },
      {
        "S",
        mode = { "n", "x", "o" },
        function()
          require("flash").treesitter()
        end,
        desc = "Flash Treesitter",
      },
      {
        mode = "o",
        "r",
        function()
          require("flash").remote()
        end,
        desc = "Remote Flash",
      },
      {
        "R",
        mode = { "o", "x" },
        function()
          require("flash").treesitter_search()
        end,
        desc = "Treesitter Search",
      },
      {
        "<c-s>",
        mode = { "c" },
        function()
          require("flash").toggle()
        end,
        desc = "Toggle Flash Search",
      },
    },
  },
  { "kevinhwang91/nvim-hlslens" },
  -- mini stuff
  --
  {
    "echasnovski/mini.nvim",
    version = "*",
    config = function()
      -- Better Around/Inside text objects
      -- Example:
      --  - va) => Select Around ()
      --  - yinq => Yank Inside Quotes
      --  -  ci'  => Change Inside Quotes
      require("mini.ai").setup({ n_lines = 500 })

      -- Add/delete/replace surrounding text objects
      -- - saiw) => Surround Around Inner Word with ()
      -- - sd' => Surround Delete '
      -- - sr)' => Surround Replace ) with '
      require("mini.surround").setup({
        mappings = {
          add= 'ya',
          delete= 'yd',
          find= 'yf',
          find_left= 'yF',
          highlight= 'yh',
          replace= 'yr',
          update_n_lines = 'yn',
          suffix_last = 'l',
          suffix_next = 'n',
        }
      })

      -- Cursor world
      require("mini.cursorword").setup()

      -- Visited paths
      require("mini.visits").setup()

      -- Highlighters
      local hipatterns = require("mini.hipatterns")
      hipatterns.setup({
        highlighters = {
          -- Highlight hex color strings (`#rrggbb`) using that color
          hex_color = hipatterns.gen_highlighter.hex_color(),
        },
      })
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.3",
    dependencies = { "nvim-lua/plenary.nvim" },
  },
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build =
    "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build",
  },
  { "smartpde/telescope-recent-files" },
  {
    "j-hui/fidget.nvim",
    tag = "legacy",
    event = "LspAttach",
    opts = {
      -- options
    },
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
      "MunifTanjim/nui.nvim",
    },
  },
  -- { "MunifTanjim/nui.nvim" },
  { "folke/which-key.nvim" },
  {
    "mg979/vim-visual-multi",
    branch = "master",
  },
  { "akinsho/toggleterm.nvim", version = "*", config = true },
  {
    "junegunn/fzf",
    build = function()
      vim.fn["fzf#install"]()
    end,
  },
  {
    "danymat/neogen",
    dependencies = "nvim-treesitter/nvim-treesitter",
    config = true,
  },
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        suggestion = {
          enabled = true,
          auto_trigger = true,
          debounce = 50,
          keymap = {
            accept = "<M-l>",
            next = "<M-j>",
            prev = "<M-k>",
            dismiss = "<M-h>",
          },
        },
      })
    end,
  },
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {
      cmdline = {
        format = {
          cmdline = {
            icon = "󰅬",
          },
        },
      },
      views = {
        cmdline_popup = {
          position = {
            row = 10,
            col = "50%",
          },
          size = {
            height = "auto",
            width = 60,
          },
        },
        popupmenu = {
          relative = "editor",
          position = "auto",
          size = {
            width = 40,
            height = 10,
          },
          border = {
            style = "rounded",
            padding = { 0, 1 },
          },
          win_options = {
            winhighlight = { Normal = "Normal", FloatBorder = "DiagnosticInfo" },
          },
        },
      },
      routes = {
        {
          filter = {
            event = "msg_show",
            kind = "",
            find = "written",
          },
          opts = { skip = true },
        },
        {
          filter = {
            event = "msg_show",
            kind = "search_count",
          },
          opts = { skip = true },
        },
      },
      lsp = {
        -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
        progress = {
          enabled = false,
        },
      },
      messages = {
        view_search = false,
      },
      -- you can enable a preset for easier configuration
      presets = {
        bottom_search = false,    -- use a classic bottom cmdline for search
        command_palette = true,   -- position the cmdline and popupmenu together
        long_message_to_split = true, -- long messages will be sent to a split
        inc_rename = false,       -- enables an input dialog for inc-rename.nvim
        lsp_doc_border = true,    -- add a border to hover docs and signature help
      },
    },
    dependencies = {
      -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
      "MunifTanjim/nui.nvim",
      -- OPTIONAL:
      --   `nvim-notify` is only needed, if you want to use the notification view.
      --   If not available, we use `mini` as the fallback
      "rcarriga/nvim-notify",
    },
  },
  {
    "rcarriga/nvim-notify",
    event = "VeryLazy",
    config = function()
      require("notify").setup({
        timeout = 300,
        max_width = 50,
        top_down = false,
      })
    end,
  },
  {
    "stevearc/oil.nvim",
    opts = {
      keymaps = {
        ["q"] = "actions.close",
      },
    },
    -- Optional dependencies
    dependencies = { "nvim-tree/nvim-web-devicons" },
  },
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    },
  },
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = "nvim-tree/nvim-web-devicons",
    config = function()
      require("bufferline").setup({
        options = {
          hover = {
            enable = true,
            delay = 200,
            reveal = { "close" },
          },
          diagnostics = "nvim_lsp",
          diagnostics_indicator = function(count, level)
            local icon = level:match("error") and " " or ""
            return " " .. icon .. count
          end,
          offsets = {
            {
              filetype = "NvimTree",
              text = function()
                return vim.fn.getcwd()
              end,
              highlight = "Directory",
            },
          },
        },
      })
    end,
  },
  {
    'chentoast/marks.nvim',
    config = function ()
      require('marks').setup({
        default_mappings = true,
      })
    end
  }
}
local opts = {}
require("lazy").setup(plugins, opts)
