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
		formatting.prettierd.with({
			filetypes = { "javascript", "scss", "css", "typescript", "json", "html", "vue" },
		}), -- js/ts formatter
		formatting.phpcsfixer.with({
			filetypes = { "php" },
		}),
		formatting.blade_formatter.with({
			filetypes = { "blade" },
		}),
		formatting.stylua.with({
			filetypes = { "lua" },
		}), -- lua formatter
		code_actions.eslint_d,
		code_actions.cspell,
		diagnostics.cspell,
		diagnostics.eslint_d.with({ -- js/ts lint
			condition = function(utils)
				return utils.root_has_file(".eslintrc.js") -- change file extension if you use something else
			end,
		}),
	},
	-- configure format on save
	on_attach = function(current_client, bufnr)
		if current_client.name == "tsserver" then
			current_client.resolved_capabilities.document_formatting = false
		end
	end,
})
