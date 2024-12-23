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
							-- require("luasnip.loaders.from_vscode").lazy_load()
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
					preset = "enter",
					["<C-o>"] = { "select_and_accept", "fallback" },
					["<Tab>"] = { "select_next", "fallback" },
					["<S-Tab>"] = { "select_prev", "fallback" },
					["<C-f>"] = { "snippet_forward", "fallback" },
					["<C-b>"] = { "snippet_backward", "fallback" },
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
                min_keyword_length = function (ctx)
                    if ctx.mode == 'cmdline' and string.find(ctx.line, ' ') == nil then return 2 end
                    return 0
                end
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
