return {
	{
		"akinsho/git-conflict.nvim",
		version = "*",
		config = function()
			require("git-conflict").setup({
				default_mappings = true,
				default_commands = true,
				disable_diagnostics = true,
				list_opener = "copen",
				highlights = {
					incoming = "DiffAdd",
					current = "DiffText",
				},
			})
			vim.keymap.set("n", "co", "<Plug>(git-conflict-ours)", { desc = "git conflict - choose ours" })
			vim.keymap.set("n", "ct", "<Plug>(git-conflict-theirs)", { desc = "git conflict - choose theirs" })
			vim.keymap.set("n", "cb", "<Plug>(git-conflict-both)", { desc = "git conflict - choose both" })
			vim.keymap.set("n", "c0", "<Plug>(git-conflict-none)", { desc = "git conflict - choose none" })
			vim.keymap.set(
				"n",
				"cp",
				"<Plug>(git-conflict-prev-conflict)",
				{ desc = "git conflict - previous conflict" }
			)
			vim.keymap.set("n", "cn", "<Plug>(git-conflict-next-conflict)", { desc = "git conflict - next conflict" })
		end,
	},
	{
		"NeogitOrg/neogit",
		dependencies = {
			"nvim-lua/plenary.nvim", -- required
			"sindrets/diffview.nvim", -- optional - Diff integration

			-- Only one of these is needed.
            -- "ibhagwan/fzf-lua", -- optional
			"echasnovski/mini.nvim", -- optional
		},
		config = function()
			require("neogit").setup({
				integrations = {
					diffview = true,
					telescope = true,
					-- fzf = true,
					mini = true,
				},
			})
			vim.api.nvim_set_keymap("n", "<leader>gg", "<ESC><cmd>Neogit<CR>", { noremap = true })
		end,
	},
	{
		"lewis6991/gitsigns.nvim",
	       event = "BufRead",
		keys = {
			{ "gn", "<cmd>Gitsigns next_hunk<cr>", desc = "Gitsigns - Goto next hunk" },
			{ "gp", "<cmd>Gitsigns prev_hunk<cr>", desc = "Gitsigns - Goto previous hunk" },
			{ "<leader>ph", "<CMD>Gitsigns preview_hunk<CR>", desc = "Gitsigns - Preview hunk" },
			{ "<leader>df", "<CMD>DiffviewFileHistory %<CR>", desc = "Diffview File History", mode = {"n", "v"} },
	           { "<leader>dq", "<CMD>DiffviewClose<CR>", desc = "Diffview Close" },
	           { "<leader>do", "<CMD>DiffviewOpen<CR>", desc = "Diffview Open" },
		},
		config = function()
			require("gitsigns").setup({
				signs = {
					add = { text = "┃" },
					change = { text = "┃" },
					delete = { text = "_" },
					topdelete = { text = "‾" },
					changedelete = { text = "~" },
					untracked = { text = "┆" },
				},
				signs_staged = {
					add = { text = "┃" },
					change = { text = "┃" },
					delete = { text = "_" },
					topdelete = { text = "‾" },
					changedelete = { text = "~" },
					untracked = { text = "┆" },
				},
				signs_staged_enable = true,
				signcolumn = true, -- Toggle with `:Gitsigns toggle_signs`
				numhl = true, -- Toggle with `:Gitsigns toggle_numhl`
				linehl = false, -- Toggle with `:Gitsigns toggle_linehl`
				word_diff = false, -- Toggle with `:Gitsigns toggle_word_diff`
				watch_gitdir = {
					follow_files = true,
				},
				auto_attach = true,
				attach_to_untracked = false,
				current_line_blame = true, -- Toggle with `:Gitsigns toggle_current_line_blame`
				current_line_blame_opts = {
					virt_text = true,
					virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
					delay = 500,
					ignore_whitespace = false,
					virt_text_priority = 500,
					use_focus = true,
				},
				current_line_blame_formatter = " <author>, <author_time:%R> - <summary>",
				sign_priority = 6,
				update_debounce = 100,
				status_formatter = nil, -- Use default
				max_file_length = 40000, -- Disable if file is longer than this (in lines)
				preview_config = {
					-- Options passed to nvim_open_win
					border = "single",
					style = "minimal",
					relative = "cursor",
					row = 0,
					col = 1,
				},
			})
		end,
	},
}
