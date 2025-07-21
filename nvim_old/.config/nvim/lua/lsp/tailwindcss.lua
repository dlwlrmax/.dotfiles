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
			init_options = {
				userLanguages = {
					vue = "html",
				},
				blade = {
					filetypes = { "blade" },
				},
			},
			settings = {
				tailwindCSS = {
					experimental = {
						classRegex = {
							'class="([^"]*)"', -- Standard HTML/Vue/Blade
							'class: "[^"]*"', -- Vue/Inertia class bindings
							"\\$classes\\([^)]+\\)", -- Laravel PHP $classes() helper
						},
					},
					includeLanguages = {
						vue = "html",
					},
					validate = false,
					emmetCompletions = false,
				},
			},
		})
	end,
}
