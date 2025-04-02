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
                    {
                        ft = "dbout",
                        size = { height = 0.5 },
                        title = "Database Output"
                    }
				},
				left = {
					-- Neo-tree filesystem always takes half the screen height
					-- {
					-- 	title = "File Explorer",
					-- 	ft = "snacks_picker_list",
					-- 	filter = function(buf)
					-- 		return vim.b[buf].neo_tree_source == "filesystem"
					-- 	end,
					-- 	size = { height = 0.5 },
					-- },
                    {
                        ft = "dbui",
                        size = { height = 0.5 },
                    }
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
					-- close window
					["q"] = function(win)
						win:close()
					end,
					-- hide window
					["<c-q>"] = function(win)
						win:hide()
					end,
					["Q"] = function(win)
						win.view.edgebar:close()
					end,
					["]w"] = function(win)
						win:next({ visible = true, focus = true })
					end,
					["[w"] = function(win)
						win:prev({ visible = true, focus = true })
					end,
					["]W"] = function(win)
						win:next({ pinned = false, focus = true })
					end,
					["[W"] = function(win)
						win:prev({ pinned = false, focus = true })
					end,
				},
				animate = {
					enabled = false,
				},
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
