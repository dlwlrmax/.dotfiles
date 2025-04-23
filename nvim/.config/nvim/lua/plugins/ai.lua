return {
	-- {
	-- 	"zbirenbaum/copilot.lua",
	-- 	cmd = "Copilot",
	-- 	event = "InsertEnter",
	-- 	config = function()
	-- 		require("copilot").setup({
	-- 			panel = {
	-- 				enabled = true,
	-- 				auto_refresh = false,
	-- 				keymap = {
	-- 					jump_prev = "[[",
	-- 					jump_next = "]]",
	-- 					accept = "<CR>",
	-- 					refresh = "gr",
	-- 					open = "<M-CR>",
	-- 				},
	-- 				layout = {
	-- 					position = "bottom", -- | top | left | right
	-- 					ratio = 0.4,
	-- 				},
	-- 			},
	-- 			suggestion = {
	-- 				enabled = true,
	-- 				auto_trigger = true,
	-- 				hide_during_completion = false,
	-- 				debounce = 75,
	-- 				keymap = {
	-- 					accept = "<M-l>",
	-- 					accept_word = "<M-w>",
	-- 					accept_line = false,
	-- 					next = "<M-]>",
	-- 					prev = "<M-[>",
	-- 					dismiss = "<C-]>",
	-- 				},
	-- 			},
	-- 			filetypes = {
	-- 				yaml = false,
	-- 				markdown = true,
	-- 				help = false,
	-- 				gitcommit = true,
	-- 				gitrebase = true,
	-- 				hgcommit = false,
	-- 				svn = false,
	-- 				cvs = false,
	-- 				["."] = false,
	-- 			},
	-- 			copilot_node_command = "node", -- Node.js version must be > 18.x
	-- 			server_opts_overrides = {},
	-- 		})
	-- 	end,
	-- },
	-- {
	-- 	"yetone/avante.nvim",
	-- 	event = "VeryLazy",
	-- 	lazy = false,
	-- 	version = false, -- set this if you want to always pull the latest change
	-- 	opts = {
	-- 		provider = "copilot",
	-- 		behaviour = {
	-- 			auto_suggestions = false,
	-- 		},
	-- 		-- remove default mappings
	-- 		mappings = {
	-- 			ask = "<leader>ua",
	-- 			edit = "<leader>ue",
	-- 			refresh = "<leader>ur",
	-- 			switch = "<leader>ua",
	-- 		},
	-- 		windows = {
	-- 			position = "right",
	-- 			wrap = true,
	-- 			width = 40,
	-- 			ask = {
	-- 				start_insert = true,
	-- 			},
	-- 		},
	-- 	},
	-- 	-- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
	-- 	build = "make",
	-- 	-- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
	-- 	dependencies = {
	-- 		"nvim-treesitter/nvim-treesitter",
	-- 		"stevearc/dressing.nvim",
	-- 		"nvim-lua/plenary.nvim",
	-- 		"MunifTanjim/nui.nvim",
	-- 		--- The below dependencies are optional,
	-- 		"nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
	-- 		"zbirenbaum/copilot.lua", -- for providers='copilot'
	-- 		{
	-- 			-- Make sure to set this up properly if you have lazy=true
	-- 			"MeanderingProgrammer/render-markdown.nvim",
	-- 			opts = {
	-- 				file_types = { "markdown", "Avante" },
	-- 			},
	-- 			ft = { "markdown", "Avante" },
	-- 		},
	-- 	},
	-- },

	{
		"Exafunction/windsurf.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"saghen/blink.cmp",
		},
        -- commit = "9569c9095a70370849345c861cdb2b06c4cadac7",
		config = function()
			require("codeium").setup({
				enable_cmp_source = false,
				virtual_text = {
					enabled = true,
					quiet = true,
                    filetypes = {
                        markdown = false
                    },
                    default_filetype_enabled = true,
					key_bindings = {
						accept = "<M-l>",
						accept_word = "<M-w>",
						accept_line = false,
						idle_delay = 100,
						next = "<M-]>",
						prev = "<M-[>",
						dismiss = "<C-]>",
					},
				},
			})
		end,
	},
}
