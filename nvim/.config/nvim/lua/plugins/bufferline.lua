-- if true then return {} end
return {
	{
		"akinsho/bufferline.nvim",
		version = "*",
		event = "VeryLazy",
		dependencies = "nvim-tree/nvim-web-devicons",
		opts = function()
			local Offset = require("bufferline.offset")
			if not Offset.edgy then
				local get = Offset.get
				Offset.get = function()
					if package.loaded.edgy then
						local old_offset = get()
						local layout = require("edgy.config").layout
						local ret = { left = "", left_size = 0, right = "", right_size = 0 }
						for _, pos in ipairs({ "left", "right" }) do
							local sb = layout[pos]
							local title = " Sidebar" .. string.rep(" ", sb.bounds.width - 8)
							if sb and #sb.wins > 0 then
								ret[pos] = old_offset[pos .. "_size"] > 0 and old_offset[pos]
									or pos == "left" and ("%#Bold#" .. title .. "%*" .. "%#BufferLineOffsetSeparator#│%*")
									or pos == "right"
										and ("%#BufferLineOffsetSeparator#│%*" .. "%#Bold#" .. title .. "%*")
								ret[pos .. "_size"] = old_offset[pos .. "_size"] > 0 and old_offset[pos .. "_size"]
									or sb.bounds.width
							end
						end
						ret.total_size = ret.left_size + ret.right_size
						if ret.total_size > 0 then
							return ret
						end
					end
					return get()
				end
				Offset.edgy = true
			end
		end,
		keys = {
			{ "<leader>h", "<Cmd>BufferLineCyclePrev<CR><CR>", desc = "Previous buffer", mode = { "n", "v" } },
			{ "<leader>l", "<Cmd>BufferLineCycleNext<CR>", desc = "Next buffer", mode = { "n", "v" } },
			{ "<leader>ml", "<Cmd>BufferLineMoveNext<CR><CR>", desc = "Move buffer right", mode = { "n", "v" } },
			{ "<leader>mh", "<Cmd>BufferLineMovePrev<CR>", desc = "Move buffer left", mode = { "n", "v" } },
			{ "<leader>rt", "<Cmd>BufferRestore<CR>", desc = "Restore last closed buffer", mode = { "n", "v" } },
			{ "<leader><tab>", "<CMD>b#<CR>", desc = "Previous buffer", mode = { "n", "v" } },
			{ "<leader>bc", "<CMD>BufferLineCloseOthers<CR>", desc = "Close other buffers", mode = { "n", "v" } },
		},
		config = function()
			local bufferline = require("bufferline")
			local mocha = require("catppuccin.palettes").get_palette("mocha")
			bufferline.setup({
				highlights = require("catppuccin.groups.integrations.bufferline").get({
					styles = { "italic", "bold" },
				}),
				options = {
					indicator = {
						icon = "▎", -- this should be omitted if indicator style is not 'icon'
						style = "underline",
					},
					separator_style = "slope",
					diagnostics = "nvim_lsp",
					diagnostics_indicator = function(count, level)
						local icon = level:match("error") and " " or " "
						return "(" .. icon .. count .. ")"
					end,
					offsets = {
						{
							filetype = "Scratch",
							text = function()
								return vim.fn.getcwd()
							end,
							highlight = "File Explorer",
						},
					},
				},
			})
		end,
	},
}
