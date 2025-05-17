return {
	setup = function()
		vim.lsp.config("tailwindcss", {
			filetypes = { "vue", "html" },
			filetypes_exclude = { "markdown", "markdown.mdx", "markdown.pandoc" },
			root_dir = require("lspconfig.util").root_pattern(
				"tailwind.config.js",
				"tailwind.config.cjs",
				"tailwind.config.ts",
				"tailwind.config.cts"
			),
		})
	end,
}
