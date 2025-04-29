return {
	"hedyhli/outline.nvim",
	lazy = true,
	cmd = { "Outline", "OutlineOpen" },
	keys = { -- Example mapping to toggle outline
		{ "<leader>ol", "<cmd>Outline<CR>", desc = "Toggle outline" },
	},
	opts = {
        outline_window = {
            auto_close = true
        },
		preview_window = {
			auto_preview = true,
		},
	},
}
