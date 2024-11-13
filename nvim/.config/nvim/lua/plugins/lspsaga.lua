return {
    'nvimdev/lspsaga.nvim',
    dependencies = {'nvim-treesitter/nvim-treesitter', -- optional
    'nvim-tree/nvim-web-devicons' -- optional
    },
    config = function()
        require('lspsaga').setup({
            symbol_in_winbar = {
                enable = true,
                hide_keyword = true,
                show_file = true,
                folder_level = 3,
                color_mode = true,
                delay = 1000
            },
            move_in_saga = {
                prev = "<C-k>",
                next = "<C-j>"
            },
            finder_action_keys = {
                open = "<CR>",
                vsplit = "<C-v>",
                quit = "q"
            },
            code_action = {
                num_shortcut = true,
                show_server_name = true,
                extend_gitsigns = true,
                keys = {
                    -- string | table type
                    quit = "q",
                    exec = "<CR>"
                }
            },
            definition_action_keys = {
                edit = "<CR>",
                vsplit = "<C-v>",
                quit = "q"
            },
            definition = {
                edit = "<CR>",
                vsplit = "<C-v>",
                quit = "q"
            },
            lightbulb = {
                enable = true,
                enable_in_insert = false,
                sign = true,
                sign_priority = 140,
                virtual_text = false
            },
            ui = {
                -- This option only works in Neovim 0.9
                title = true,
                -- Border type can be single, double, rounded, solid, shadow.
                border = "rounded",
                winblend = 0,
                expand = "",
                collapse = "",
                code_action = "",
                incoming = " ",
                outgoing = " ",
                hover = " ",
                kind = require("catppuccin.groups.integrations.lsp_saga").custom_kind()
            }
        })
    end,
}
