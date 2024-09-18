local mason_status, mason = pcall(require, "mason")
if not mason_status then
	return
end

local navic_status, navic = pcall(require, "nvim-navic")
if not navic_status then
	return
end

local mason_lspconfig_status, mason_lspconfig = pcall(require, "mason-lspconfig")
if not mason_lspconfig_status then
	return
end

mason.setup({
	ensure_installed = {
		"typos",
		"phpactor",
		"intelephense",
		"lua_ls",
		"eslint-lsp",
		"lua-language-server",
		"typescript-language-server",
		"vue-language-server",
		"stylua",
		"php-cs-fixer",
		"prettier",
	},
})

mason_lspconfig.setup()

local mason_registry = require('mason-registry')
local vue_language_server_path = mason_registry.get_package('vue-language-server'):get_install_path() .. '/node_modules/@vue/language-server'

local on_attach = function(client, bufnr)
	if client.server_capabilities.documentSymbolProvider then
		navic.attach(client, bufnr)
	end
end

require("mason-lspconfig").setup_handlers({
	-- The first entry (without a key) will be the default handler
	-- and will be called for each installed server that doesn't have
	-- a dedicated handler.
	function(server_name) -- default handler (optional)
		require("lspconfig")[server_name].setup({
			on_attach = on_attach
		})
	end,
	-- Next, you can provide a dedicated handler for specific servers.
	-- For example, a handler override for the `rust_analyzer`:
	-- ["rust_analyzer"] = function()
	-- 	require("rust-tools").setup({})
	-- end,
	["lua_ls"] = function()
		local lspconfig = require("lspconfig")
		lspconfig.lua_ls.setup({
			settings = {
				Lua = {
					diagnostics = {
						globals = { "vim" },
					},
				},
			},
		})
	end,
	["phpactor"] = function()
		local lspconfig = require("lspconfig")
		lspconfig.phpactor.setup({
			root_dir = function(_)
				return vim.loop.cwd()
			end,
			init_options = {
				["language_server.diagnostics_on_update"] = false,
				["language_server.diagnostics_on_open"] = false,
				["language_server.diagnostics_on_save"] = false,
				["language_server.phpstan.enabled"] = true,
				["language_server.psalm.enabled"] = false,
			},
		})
	end,
	["intelephense"] = function()
		local lspconfig = require("lspconfig")
		lspconfig.intelephense.setup({
			settings = {
				intelephense = {
					files = {
						maxSize = 1000000,
					},
				},
			},
		})
	end,
	["ts_ls"] = function()
    local lspconfig = require("lspconfig")
		lspconfig.tsserver.setup({
			init_options = {
				plugins = {
					{
						name = "@vue/typescript-plugin",
						location = vue_language_server_path,
						languages = { "vue" },
					},
				},
			},
			filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" },
		})
	end,
})
