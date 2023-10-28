local set, neogen = pcall(require, "neogen")

if not set then
	return
end

neogen.setup({
	enabled = true,
	input_after_comment = true,
	snippet_engine = "luasnip",
	languages = {
		lua = {
			template = {
				annotation_convention = "emmylua", -- for a full list of annotation_conventions, see supported-languages below,
			},
		},
		php = {
			template = {
				annotation_convention = "phpdoc", -- for a full list of annotation_conventions, see supported-languages below,
			},
		},
	},
})

local opts = { noremap = true, silent = true }
vim.api.nvim_set_keymap("n", "<Leader>cc", ":lua require('neogen').generate()<CR>", opts)
