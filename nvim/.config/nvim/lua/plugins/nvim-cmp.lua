-- ~/nvim/lua/slydragonn/plugins/cmp.lua
return {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
        "hrsh7th/cmp-buffer", -- source for text in buffer
        "hrsh7th/cmp-path", -- source for file system paths
        "hrsh7th/cmp-nvim-lsp",
        {
            "L3MON4D3/LuaSnip",
            version = "v2.*",
            -- install jsregexp (optional!).
            build = "make install_jsregexp"
        }, "rafamadriz/friendly-snippets", "onsails/lspkind.nvim" -- vs-code like pictograms
    },
    config = function()
        local cmp = require("cmp")
        local lspkind = require("lspkind")
        local luasnip = require("luasnip")

        require("luasnip.loaders.from_vscode").lazy_load()

        local kind_icons = {
            Text = "󰊄 [Text]",
            Method = " [Method]",
            Function = "󰊕 [Function]",
            Constructor = " [Constructor]",
            Field = " [Field]",
            Variable = "󰫧 [Variable]",
            Class = " [Class]",
            Interface = " [Interface]",
            Module = " [Module]",
            Property = " [Property]",
            Unit = " [Unit]",
            Value = " [Value]",
            Enum = " [Enum]",
            Keyword = " [Keyword]",
            Snippet = " [Snippet]",
            Color = " [Color]",
            File = " [File]",
            Reference = " [Reference]",
            Folder = " [Folder]",
            EnumMember = " [EnumMember]",
            Constant = " [Constant]",
            Struct = " [Struct]",
            Event = " [Event]",
            Operator = " [Operator]",
            TypeParameter = "󰉺 [TypeParameter]"
        }

        cmp.setup({
            snippet = {
                expand = function(args)
                    luasnip.lsp_expand(args.body)
                end
            },
            window = {
                completion = cmp.config.window.bordered(),
                documentation = cmp.config.window.bordered()
            },
            formatting = {
                fields = {"kind", "abbr", "menu"},
                format = function(entry, vim_item)
                    -- Kind icons
                    vim_item.kind = string.format("%s", kind_icons[vim_item.kind])
                    -- vim_item.kind = string.format('%s %s', kind_icons[vim_item.kind], vim_item.kind) -- This concatonates the icons with the name of the item kind
                    vim_item.menu = ({
                        buffer = "[Buf]",
                        luasnip = "[Sni]",
                        path = "[Pat]",
                        nvim_lsp = "[LSP]"
                        -- cmp_tabnine = "[TAB]",
                    })[entry.source.name]
                    return vim_item
                end
            },
            mapping = {
                ['<Up>'] = cmp.mapping.select_prev_item(select_opts),
                ['<Down>'] = cmp.mapping.select_next_item(select_opts),

                ['<C-p>'] = cmp.mapping.select_prev_item(select_opts),
                ['<C-n>'] = cmp.mapping.select_next_item(select_opts),

                ['<C-u>'] = cmp.mapping.scroll_docs(-4),
                ['<C-d>'] = cmp.mapping.scroll_docs(4),

                ['<C-e>'] = cmp.mapping.abort(),
                ['<C-y>'] = cmp.mapping.confirm({
                    select = true
                }),
                ['<CR>'] = cmp.mapping.confirm({
                    select = false
                }),

                ['<C-f>'] = cmp.mapping(function(fallback)
                    if luasnip.jumpable(1) then
                        luasnip.jump(1)
                    else
                        fallback()
                    end
                end, {'i', 's'}),

                ['<C-b>'] = cmp.mapping(function(fallback)
                    if luasnip.jumpable(-1) then
                        luasnip.jump(-1)
                    else
                        fallback()
                    end
                end, {'i', 's'}),

                ['<Tab>'] = cmp.mapping(function(fallback)
                    local col = vim.fn.col('.') - 1

                    if cmp.visible() then
                        cmp.select_next_item(select_opts)
                    elseif col == 0 or vim.fn.getline('.'):sub(col, col):match('%s') then
                        fallback()
                    else
                        cmp.complete()
                    end
                end, {'i', 's'}),

                ['<S-Tab>'] = cmp.mapping(function(fallback)
                    if cmp.visible() then
                        cmp.select_prev_item(select_opts)
                    else
                        fallback()
                    end
                end, {'i', 's'})
            },
            sources = cmp.config.sources({{
                name = "nvim_lsp",
                keyword_length = 1
            }, {
                name = "luasnip",
                keyword_length = 2
            }, {
                name = "buffer"
            }, {
                name = "path"
            }})
        })

        vim.cmd([[
      set completeopt=menuone,noinsert,noselect
      highlight! default link CmpItemKind CmpItemMenuDefault
    ]])
    end
}