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
					-- lua = { "lazydev", "lsp", "path", "snippets", "buffer", "ripgrep" },
				},
				providers = {
					dadbod = { name = "Dadbod", module = "vim_dadbod_completion.blink" },
					codeium = { name = "Codeium", module = "codeium.blink", async = true },
					-- ecolog = { name = "ecolog", module = "ecolog.integrations.cmp.blink_cmp" },
					lsp = {
						score_offset = 99,
						timeout_ms = 3000,
					},
					snippets = {
						score_offset = 100,
						min_keyword_length = 2,
					},
					buffer = {
						min_keyword_length = 2,
						async = false,
					},
					lazydev = {
						name = "LazyDev",
						module = "lazydev.integrations.blink",
						async = false,
						score_offset = 100,
					},
					-- ripgrep = {
					-- 	module = "blink-ripgrep",
					-- 	name = "Ripgrep",
					-- 	score_offset = -10,
					-- 	-- the options below are optional, some default values are shown
					-- 	---@module "blink-ripgrep"
					-- 	---@type blink-ripgrep.Options
					-- 	opts = {
					-- 		prefix_min_len = 3,
					-- 		context_size = 5,
					-- 		max_filesize = "1M",
					-- 		project_root_marker = { ".git", "package.json" },
					-- 		project_root_fallback = true,
					-- 		-- The casing to use for the search in a format that ripgrep
					-- 		-- accepts. Defaults to "--ignore-case". See `rg --help` for all the
					-- 		-- available options ripgrep supports, but you can try
					-- 		-- "--case-sensitive" or "--smart-case".
					-- 		search_casing = "--ignore-case",
					-- 		-- (advanced) Any additional options you want to give to ripgrep.
					-- 		-- See `rg -h` for a list of all available options. Might be
					-- 		-- helpful in adjusting performance in specific situations.
					-- 		-- If you have an idea for a default, please open an issue!
					-- 		--
					-- 		-- Not everything will work (obviously).
					-- 		additional_rg_options = {},
					-- 		-- When a result is found for a file whose filetype does not have a
					-- 		-- treesitter parser installed, fall back to regex based highlighting
					-- 		-- that is bundled in Neovim.
					-- 		fallback_to_regex_highlighting = true,
					-- 		ignore_paths = {},
					-- 		additional_paths = {},
					-- 		toggles = {
					-- 			-- The keymap to toggle the plugin on and off from blink
					-- 			-- completion results. Example: "<leader>tg"
					-- 			on_off = nil,
					-- 		},
					-- 		future_features = {
					-- 			-- Workaround for
					-- 			-- https://github.com/mikavilpas/blink-ripgrep.nvim/issues/185. This
					-- 			-- is a temporary fix and will be removed in the future.
					-- 			issue185_workaround = false,
					-- 			backend = {
					-- 				use = "ripgrep",
					-- 			},
					-- 		},
					-- 		debug = false,
					-- 	},
					-- 	-- (optional) customize how the results are displayed. Many options
					-- 	-- are available - make sure your lua LSP is set up so you get
					-- 	-- autocompletion help
					-- 	transform_items = function(_, items)
					-- 		for _, item in ipairs(items) do
					-- 			-- example: append a description to easily distinguish rg results
					-- 			item.labelDetails = {
					-- 				description = "(rg)",
					-- 			}
					-- 		end
					-- 		return items
					-- 	end,
					-- },
				},
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

			fuzzy = {
				implementation = "prefer_rust_with_warning",
				sorts = {
					"score",
					"exact",
					function(item_a, item_b)
						if item_a.deprecated then
							return false
						end
					end,
					"sort_text",
				},
			},
			signature = {
				enabled = false,
				trigger = {
					enabled = true,
					show_on_trigger_character = true,
					show_on_insert = false,
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
