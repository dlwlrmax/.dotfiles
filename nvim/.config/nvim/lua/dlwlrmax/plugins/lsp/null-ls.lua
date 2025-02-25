-- import null-ls plugin safely
local setup, null_ls = pcall(require, "null-ls")
if not setup then
	return
end

local mason_status, mason = pcall(require, "mason")
if not mason_status then
	return
end

-- for conciseness
local formatting = null_ls.builtins.formatting -- to setup formatters
local diagnostics = null_ls.builtins.diagnostics -- to setup linters
local code_actions = null_ls.builtins.code_actions

-- configure null_ls
null_ls.setup({
	-- setup formatters & linters
	sources = {
		--  to disable file types use
		--  "formatting.prettier.with({disabled_filetypes: {}})" (see null-ls docs)
		formatting.prettier.with({
			filetypes = { "javascript", "scss", "css", "typescript", "json", "html", "vue" },
		}), -- js/ts formatter
		formatting.stylua.with({
			filetypes = { "lua" },
		}), -- lua formatter
		formatting.phpcsfixer.with({
			filetypes = { "php" },
		}), -- php formatter
		diagnostics.phpstan.with({
			filetypes = { "php" },
		}), -- php linter
		require("none-ls.diagnostics.eslint").with({
      method = null_ls.methods.DIAGNOSTICS_ON_SAVE,
    }), -- eslint linter
		require("none-ls.code_actions.eslint"),
		require("none-ls-php.diagnostics.php"),
	},
})
