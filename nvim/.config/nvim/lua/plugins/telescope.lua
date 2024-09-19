return {
	"nvim-telescope/telescope.nvim",
	tag = "0.1.8",
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
		local telescope = require("telescope")
		telescope.load_extension("fzf")
		telescope.load_extension("recent_files")
		telescope.setup({
			defaults = {
				file_ignore_partterns = { "node_modules", "ckeditor5", ".git" },
			},
			color_devicons = true,
			mappings = {
				n = { ["q"] = require("telescope.actions").close },
				i = {
					["<esc>"] = require("telescope.actions").close,
					["<C-j>"] = require("telescope.actions").move_selection_next,
					["<C-k>"] = require("telescope.actions").move_selection_previous,
					["<C-c>"] = require("telescope.actions").close,
					["<C-p>"] = require("telescope.actions.layout").toggle_preview,
					["<C-h>"] = require("telescope.actions").select_horizontal,
					["<C-v>"] = require("telescope.actions").select_vertical,
				},
			},
			path_display = { "truncate" },
			preview = {
				filesize_hook = function(filepath, bufnr, opts)
					local max_bytes = 10000
					local cmd = { "head", "-c", max_bytes, filepath }
					require("telescope.previewers.utils").job_maker(cmd, bufnr, opts)
				end,
			},
			extensions = {
				recent_files = {
					stat_files = true,
					only_cwd = true,
				},
				fzf = {
					fuzzy = true,
					override_generic_sorter = true,
					override_file_sorter = true,
				},
				media_files = {
					-- filetypes whitelist
					-- defaults to {"png", "jpg", "mp4", "webm", "pdf"}
					filetypes = { "png", "webp", "jpg", "jpeg" },
					-- find command (defaults to `fd`)
					find_cmd = "rg",
				},
			},
		})
	end,
}
