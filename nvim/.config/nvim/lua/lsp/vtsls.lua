return {
	setup = function()
		vim.lsp.config("vtsls", {
			filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" },
			settings = {
				vtsls = { tsserver = { globalPlugins = {} } },
			},
			before_init = function(params, config)
				local result = vim.system(
					{ "npm", "query", "#vue" },
					{ cwd = params.workspaceFolders[1].name, text = true }
				)
					:wait()
				if result.stdout ~= "[]" then
					local vuePluginConfig = {
						name = "@vue/typescript-plugin",
						location = vim.fn.expand(
							"$MASON/packages/vue-language-server/node_modules/@vue/language-server"
						),
						languages = { "vue" },
						configNamespace = "typescript",
						enableForWorkspaceTypeScriptVersions = true,
					}
					table.insert(config.settings.vtsls.tsserver.globalPlugins, vuePluginConfig)
				end
			end,
		})
	end,
}
