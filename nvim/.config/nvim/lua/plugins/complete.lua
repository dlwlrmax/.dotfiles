local function has_words_before()
	local line, col = (unpack or table.unpack)(vim.api.nvim_win_get_cursor(0))
	return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end

return {
	"saghen/blink.cmp",
	lazy = false, -- lazy loading handled internally
	-- optional: provides snippets for the snippet source
	dependencies = {
		"rafamadriz/friendly-snippets",
		{
			"L3MON4D3/LuaSnip",
			-- follow latest release.
			version = "v2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
			-- install jsregexp (optional!).
			build = "make install_jsregexp",
		},
	},

	-- use a release tag to download pre-built binaries
	version = "v0.*",
	-- OR build from source, requires nightly: https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
	-- build = 'cargo build --release',
	-- If you use nix, you can build from source using latest nightly rust with:
	-- build = 'nix run .#build-plugin',

	---@module 'blink.cmp'
	---@type blink.cmp.Config
	opts = {
		-- 'default' for mappings similar to built-in completion
		-- 'super-tab' for mappings similar to vscode (tab to accept, arrow keys to navigate)
		-- 'enter' for mappings similar to 'super-tab' but with 'enter' to accept
		-- see the "default configuration" section below for full documentation on how to define
		-- your own keymap.
		keymap = {
			preset = "super-tab",
			["<CR>"] = { "accept", "fallback" },
			["<Tab>"] = {
				function(cmp)
					if cmp.windows.autocomplete.win:is_open() then
						return cmp.select_next()
					elseif cmp.is_in_snippet() then
						return cmp.snippet_forward()
					elseif has_words_before() then
						return cmp.show()
					end
				end,
				"fallback",
			},
			["<S-Tab>"] = {
				function(cmp)
					if cmp.windows.autocomplete.win:is_open() then
						return cmp.select_prev()
					elseif cmp.is_in_snippet() then
						return cmp.snippet_backward()
					end
				end,
				"fallback",
			},
		},
		sources = {
			completion = {
				enabled_providers = { "lsp", "snippets", "path", "buffer" },
			},
		},

		highlight = {
			-- sets the fallback highlight groups to nvim-cmp's highlight groups
			-- useful for when your theme doesn't support blink.cmp
			-- will be removed in a future release, assuming themes add support
			use_nvim_cmp_as_default = true,
		},
		-- set to 'mono' for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
		-- adjusts spacing to ensure icons are aligned
		nerd_font_variant = "normal",

		-- experimental auto-brackets support
		accept = { auto_brackets = { enabled = true } },

		-- experimental signature help support
		-- trigger = { signature_help = { enabled = true } },
		windows = {
			autocomplete = {
				min_width = 1,
				max_height = 20,
				border = "double",
				draw = "reversed",
			},
			documentation = {
				auto_show = true,
				border = "double",
			},
			signature_help = {
				border = "rounded",
			},
		},
	},
	-- allows extending the enabled_providers array elsewhere in your config
	-- without having to redefining it
	opts_extend = { "sources.completion.enabled_providers" },
}
