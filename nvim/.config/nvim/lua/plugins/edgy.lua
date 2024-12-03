return {
	{
		"folke/edgy.nvim",
		event = "VeryLazy",
		init = function()
			vim.opt.laststatus = 3
			vim.opt.splitkeep = "screen"
		end,
		opts = function()
			local opts = {
				bottom = {
					{
						ft = "toggleterm",
						size = { height = 0.4 },
						filter = function(buf, win)
							return vim.api.nvim_win_get_config(win).relative == ""
						end,
					},
					{
						ft = "noice",
						size = { height = 0.4 },
						filter = function(buf, win)
							return vim.api.nvim_win_get_config(win).relative == ""
						end,
					},
					"Trouble",
					{ ft = "qf", title = "QuickFix" },
					{
						ft = "help",
						size = { height = 20 },
						-- don't open help files in edgy that we're editing
						filter = function(buf)
							return vim.bo[buf].buftype == "help"
						end,
					},
					{ title = "Spectre", ft = "spectre_panel", size = { height = 0.4 } },
					{ title = "Neotest Output", ft = "neotest-output-panel", size = { height = 15 } },
				},
				left = {
					-- Neo-tree filesystem always takes half the screen height
					{
						title = "Neo-Tree",
						ft = "neo-tree",
						filter = function(buf)
							return vim.b[buf].neo_tree_source == "filesystem"
						end,
						size = { height = 0.5 },
					},
					{
						title = "Neo-Tree Git",
						ft = "neo-tree",
						filter = function(buf)
							return vim.b[buf].neo_tree_source == "git_status"
						end,
						pinned = true,
						collapsed = false, -- show window as closed/collapsed on start
						open = "Neotree position=right git_status",
					},
					{
						title = "Neo-Tree Buffers",
						ft = "neo-tree",
						filter = function(buf)
							return vim.b[buf].neo_tree_source == "buffers"
						end,
						pinned = true,
						collapsed = true, -- show window as closed/collapsed on start
						open = "Neotree position=top buffers",
					},
					{
						title = function()
							local buf_name = vim.api.nvim_buf_get_name(0) or "[No Name]"
							return vim.fn.fnamemodify(buf_name, ":t")
						end,
						ft = "Outline",
						pinned = true,
						open = "SymbolsOutlineOpen",
					},
					-- any other neo-tree windows
					"neo-tree",
				},
				right = {
					{ title = "Grug Far", ft = "grug-far", size = { width = 0.4 } },
				},
				keys = {
					-- increase width
					["<c-Right>"] = function(win)
						win:resize("width", 5)
					end,
					-- decrease width
					["<c-Left>"] = function(win)
						win:resize("width", -5)
					end,
					-- increase height
					["<c-Up>"] = function(win)
						win:resize("height", 5)
					end,
					-- decrease height
					["<c-Down>"] = function(win)
						win:resize("height", -5)
					end,
				},
                animate = {
                    enabled = false,
                }
			}

			-- trouble
			for _, pos in ipairs({ "top", "bottom", "left", "right" }) do
				opts[pos] = opts[pos] or {}
				table.insert(opts[pos], {
					ft = "trouble",
					filter = function(_buf, win)
						return vim.w[win].trouble
							and vim.w[win].trouble.position == pos
							and vim.w[win].trouble.type == "split"
							and vim.w[win].trouble.relative == "editor"
							and not vim.w[win].trouble_preview
					end,
				})
			end

			-- snacks terminal
			for _, pos in ipairs({ "top", "bottom", "left", "right" }) do
				opts[pos] = opts[pos] or {}
				table.insert(opts[pos], {
					ft = "snacks_terminal",
					size = { height = 0.4 },
					title = "%{b:snacks_terminal.id}: %{b:term_title}",
					filter = function(_buf, win)
						return vim.w[win].snacks_win
							and vim.w[win].snacks_win.position == pos
							and vim.w[win].snacks_win.relative == "editor"
							and not vim.w[win].trouble_preview
					end,
				})
			end
			return opts
		end,
	},
}
