return {
	setup = function()
		vim.lsp.config("tailwindcss", {
            cmd = {
                "node",
                "--max-old-space-size=4096",
                "$MASON/packages/tailwindcss-language-server/node_modules/@tailwindcss/language-server/bin/css-language-server",
                "--stdio"

            },
			filetypes = { "vue", "html", "javascriptreact", "typescriptreact" },
			filetypes_exclude = { "markdown", "markdown.mdx", "markdown.pandoc" },
			root_dir = require("lspconfig").util.root_pattern(
				"tailwind.config.js",
				"tailwind.config.ts",
				"postcss.config.js",
				"postcss.config.ts",
				"windi.config.ts"
			),
		})
	end,
}
