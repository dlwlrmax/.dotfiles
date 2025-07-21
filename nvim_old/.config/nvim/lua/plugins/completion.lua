return {
	{
		"saghen/blink.cmp",
		dependencies = {
			-- "mikavilpas/blink-ripgrep.nvim",
			"folke/snacks.nvim",
			{
				"L3MON4D3/LuaSnip",
				version = "v2.*",
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
		version = "*",
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
				["<C-space>"] = { "show", "hide", "fallback" },
				["<C-c>"] = { "hide", "fallback" },
			},
			cmdline = {
				keymap = {
					preset = "cmdline",
					["<C-o>"] = { "select_accept_and_enter", "fallback" },
				},
				completion = {
					ghost_text = {
						enabled = true,
					},
					menu = {
						auto_show = false,
					},
				},
			},
			snippets = {
				preset = "luasnip",
			},
			sources = {
				-- default = { "lsp", "path", "snippets", "buffer" },
				default = { "lsp", "path", "snippets", "buffer", "codeium" },
				per_filetype = {
					sql = { "dadbod", "buffer", "snippets" },
					mysql = { "dadbod", "buffer", "snippets" },
					lua = { "lazydev", "lsp", "path", "snippets", "buffer" },
				},
				providers = {
					dadbod = { name = "Dadbod", module = "vim_dadbod_completion.blink" },
					codeium = { name = "Codeium", module = "codeium.blink", async = true },
					lazydev = {
						name = "LazyDev",
						module = "lazydev.integrations.blink",
						async = false,
						score_offset = 10,
					},
				},
			},

			fuzzy = { implementation = "prefer_rust_with_warning" },

			completion = {
				accept = {
					auto_brackets = {
						enabled = true,
					},
				},
				menu = {
					border = "rounded",
					draw = {
						columns = { { "kind_icon", "label", gap = 1 }, { "source_name", "kind", gap = 1 } },
						components = {
							label = {
								width = { fill = true, max = 60 },
								text = function(ctx)
									local highlights_info = require("colorful-menu").blink_highlights(ctx)
									if highlights_info ~= nil then
										-- Or you want to add more item to label
										return highlights_info.label
									else
										return ctx.label
									end
								end,
								highlight = function(ctx)
									local highlights = {}
									local highlights_info = require("colorful-menu").blink_highlights(ctx)
									if highlights_info ~= nil then
										highlights = highlights_info.highlights
									end
									for _, idx in ipairs(ctx.label_matched_indices) do
										table.insert(highlights, { idx, idx + 1, group = "BlinkCmpLabelMatch" })
									end
									return highlights
								end,
							},
						},
					},
					auto_show = true,
				},
				documentation = {
					window = {
						border = "rounded",
					},
					auto_show = true,
					auto_show_delay_ms = 500,
				},
				list = {
					selection = { preselect = false, auto_insert = true },
				},
			},
		},
		opts_extend = { "sources.default" },
	},
	{
		"xzbdmw/colorful-menu.nvim",
		config = function()
			require("colorful-menu").setup({
				ls = {
					lua_ls = {
						-- Maybe you want to dim arguments a bit.
						arguments_hl = "@comment",
					},
					gopls = {
						align_type_to_right = true,
						add_colon_before_type = false,
						preserve_type_when_truncate = true,
					},
					ts_ls = {
						extra_info_hl = "@comment",
					},
					vtsls = {
						extra_info_hl = "@comment",
					},
					["rust-analyzer"] = {
						extra_info_hl = "@comment",
						align_type_to_right = true,
						preserve_type_when_truncate = true,
					},
					clangd = {
						extra_info_hl = "@comment",
						align_type_to_right = true,
						import_dot_hl = "@comment",
						preserve_type_when_truncate = true,
					},
					zls = {
						align_type_to_right = true,
					},
					roslyn = {
						extra_info_hl = "@comment",
					},
					dartls = {
						extra_info_hl = "@comment",
					},
					basedpyright = {
						extra_info_hl = "@comment",
					},
					fallback = true,
					fallback_extra_info_hl = "@comment",
				},
				fallback_highlight = "@variable",
				max_width = 60,
			})
		end,
	},
}
