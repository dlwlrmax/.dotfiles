---@diagnostic disable: missing-fields
return {
	{
		"saghen/blink.cmp",
		-- optional: provides snippets for the snippet source
		dependencies = {
			{
				"L3MON4D3/LuaSnip",
				-- follow latest release.
				version = "v2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
				-- install jsregexp (optional!).
				build = "make install_jsregexp",
				dependencies = {
					{
						"rafamadriz/friendly-snippets",
						config = function()
							require("luasnip.loaders.from_vscode").lazy_load()
							require("luasnip.loaders.from_vscode").lazy_load({
								paths = "~/.config/nvim/lua/snippets/vs_code",
							})
						end,
					},
				},
			},
		},

		-- use a release tag to download pre-built binaries
		version = "v0.*",
		---@module 'blink.cmp'
		---@type blink.cmp.Config
		opts = {
			keymap = {
				preset = "enter",
				["<C-o>"] = { "select_and_accept", "fallback" },
				["<Tab>"] = { "select_next", "fallback" },
				["<S-Tab>"] = { "select_prev", "fallback" },
				["<C-f>"] = { "snippet_forward", "fallback" },
				["<C-b>"] = { "snippet_backward", "fallback" },
				["<C-a>"] = { "show", "hide", "fallback" },
				cmdline = {
					preset = "default",
					["<CR>"] = { "select_and_accept", "fallback" },
					["<C-o>"] = { "select_and_accept", "fallback" },
					["<Tab>"] = { "select_next", "fallback" },
					["<S-Tab>"] = { "select_prev", "fallback" },
					["<C-a>"] = { "show", "hide", "fallback" },
				},
			},

			snippets = {
				expand = function(snippet)
					require("luasnip").lsp_expand(snippet)
				end,
				active = function(filter)
					if filter and filter.direction then
						return require("luasnip").jumpable(filter.direction)
					end
					return require("luasnip").in_snippet()
				end,
				jump = function(direction)
					require("luasnip").jump(direction)
				end,
			},

			---@diagnostic disable-next-line: missing-fields
			appearance = {
				use_nvim_cmp_as_default = true,
				nerd_font_variant = "mono",
			},

			---@diagnostic disable-next-line: missing-fields
			sources = {
				default = { "lsp", "path", "luasnip", "buffer" },
				providers = {
					lsp = {
						name = "LSP",
						module = "blink.cmp.sources.lsp",
						opts = {}, -- Passed to the source directly, varies by source
						enabled = true, -- Whether or not to enable the provider
						async = false, -- Whether we should wait for the provider to return before showing the completions
						timeout_ms = 2000, -- How long to wait for the provider to return before showing completions and treating it as asynchronous
						transform_items = nil, -- Function to transform the items before they're returned
						should_show_items = true, -- Whether or not to show the items
						max_items = nil, -- Maximum number of items to display in the menu
						min_keyword_length = 0, -- Minimum number of characters in the keyword to trigger the provider
						-- If this provider returns 0 items, it will fallback to these providers.
						-- If multiple providers falback to the same provider, all of the providers must return 0 items for it to fallback
						fallbacks = {},
						score_offset = 1000, -- Boost/penalize the score of the items
						override = nil, -- Override the source's functions
					},
                    luasnip = {
                        name = "LuaSnip",
                        module = "blink.cmp.sources.luasnip",
                        opts = {},
                        enabled = true,
                        async = false,
                        timeout_ms = 2000,
                        transform_items = nil,
                        should_show_items = true,
                        max_items = nil,
                        min_keyword_length = 0,
                        fallbacks = {},
                        score_offset = 900,
                        override = nil,
                    },
                    path = {
                        name = "Path",
                        module = "blink.cmp.sources.path",
                        opts = {},
                        enabled = true,
                        async = false,
                        timeout_ms = 2000,
                        transform_items = nil,
                        should_show_items = true,
                        max_items = nil,
                        min_keyword_length = 0,
                        fallbacks = {},
                        score_offset = 800,
                        override = nil,
                    },
				},
				cmdline = function()
					local type = vim.fn.getcmdtype()
					-- Search forward and backward
					if type == "/" or type == "?" then
						return { "buffer" }
					end
					-- Commands
					if type == ":" then
						return { "cmdline", "path" }
					end
					return {}
				end,
				min_keyword_length = function(ctx)
					if ctx.mode == "cmdline" and string.find(ctx.line, " ") == nil then
						return 2
					end
					return 0
				end,
			},

			completion = {
				accept = {
					auto_brackets = {
						enabled = true,
					},
				},
				menu = {
					border = "rounded",
					draw = {
						columns = {
							{ "label", "label_description", gap = 1 },
							{ "kind_icon", "kind", "source_name", gap = 1 },
						},
					},
				},
				documentation = {
					window = {
						border = "rounded",
					},
					auto_show = true,
					auto_show_delay_ms = 200,
				},
				list = {
					selection = "auto_insert",
				},
			},

			signature = {
				enabled = false,
			},
		},
		opts_extend = { "sources.default" },
	},
}
