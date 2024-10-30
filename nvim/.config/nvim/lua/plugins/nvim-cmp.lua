-- ~/nvim/lua/slydragonn/plugins/cmp.lua
return {
	"hrsh7th/nvim-cmp",
	dependencies = {
		"hrsh7th/cmp-buffer", -- source for text in buffer
		"hrsh7th/cmp-path", -- source for file system paths
		"hrsh7th/cmp-nvim-lsp",
		"hrsh7th/cmp-cmdline",
		"saadparwaiz1/cmp_luasnip",
		{
			"L3MON4D3/LuaSnip",
			version = "v2.*",
			-- install jsregexp (optional!).
			build = "make install_jsregexp",
		},
		"rafamadriz/friendly-snippets",
		"onsails/lspkind.nvim", -- vs-code like pictograms
	},
	config = function()
		local cmp = require("cmp")
		local lspkind = require("lspkind")
		local luasnip = require("luasnip")

		require("luasnip.loaders.from_vscode").lazy_load()
		-- require("luasnip.loaders.from_lua").load({
		-- 	paths = { "~/.config/nvim/lua/snippets/common.lua" },
		-- }) -- working on this
		require("luasnip.loaders.from_vscode").lazy_load({ paths = "~/.config/nvim/lua/snippets/vs_code" })

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
			TypeParameter = "󰉺 [TypeParameter]",
		}

		cmp.setup({
			snippet = {
				expand = function(args)
					luasnip.lsp_expand(args.body)
				end,
			},
			window = {
				completion = cmp.config.window.bordered(),
				documentation = cmp.config.window.bordered(),
			},
			formatting = {
				fields = { "kind", "abbr", "menu" },
				format = function(entry, vim_item)
					-- Kind icons
					vim_item.kind = string.format("%s", kind_icons[vim_item.kind])
					vim_item.menu = ({
						buffer = "[Buf]",
						luasnip = "[Sni]",
						path = "[Pat]",
						nvim_lsp = "[LSP]",
						-- cmp_tabnine = "[TAB]",
					})[entry.source.name]
					return vim_item
				end,
			},
			mapping = {
				["<C-p>"] = cmp.mapping.select_prev_item(select_opts),
				["<C-n>"] = cmp.mapping.select_next_item(select_opts),

				["<C-u>"] = cmp.mapping.scroll_docs(-4),
				["<C-d>"] = cmp.mapping.scroll_docs(4),

				["<C-e>"] = cmp.mapping.abort(),
				["<C-y>"] = cmp.mapping.confirm({
					select = true,
				}),

				["<C-f>"] = cmp.mapping(function(fallback)
					if luasnip.jumpable(1) then
						luasnip.jump(1)
					else
						fallback()
					end
				end, { "i", "s" }),

				["<C-b>"] = cmp.mapping(function(fallback)
					if luasnip.jumpable(-1) then
						luasnip.jump(-1)
					else
						fallback()
					end
				end, { "i", "s" }),

				["<CR>"] = cmp.mapping(function(fallback)
					if cmp.visible() then
						if luasnip.expandable() then
							luasnip.expand()
						else
							cmp.confirm({
								select = true,
							})
						end
					else
						fallback()
					end
				end),

				["<Tab>"] = cmp.mapping(function(fallback)
					if cmp.visible() then
						cmp.select_next_item()
					elseif luasnip.locally_jumpable(1) then
						luasnip.jump(1)
					else
						fallback()
					end
				end, { "i", "s" }),

				["<S-Tab>"] = cmp.mapping(function(fallback)
					if cmp.visible() then
						cmp.select_prev_item()
					elseif luasnip.locally_jumpable(-1) then
						luasnip.jump(-1)
					else
						fallback()
					end
				end, { "i", "s" }),
			},
			sources = cmp.config.sources({
				{
					name = "nvim_lsp",
				},
				{
					name = "luasnip",
				},
				{
					name = "buffer",
				},
				{
					name = "path",
				},
			}),
		})

		cmp.setup.cmdline(":", {
			mapping = cmp.mapping.preset.cmdline(),
			sources = cmp.config.sources({
				{ name = "path" },
			}, {
				{
					name = "cmdline",
					option = {
						ignore_cmds = { "Man", "!" },
					},
				},
			}),
		})
		cmp.setup.cmdline("/", {
			mapping = cmp.mapping.preset.cmdline(),
			sources = {
				{ name = "buffer" },
			},
		})
		vim.cmd([[
      set completeopt=menuone,noinsert,noselect
      highlight! default link CmpItemKind CmpItemMenuDefault
    ]])
	end,
}
