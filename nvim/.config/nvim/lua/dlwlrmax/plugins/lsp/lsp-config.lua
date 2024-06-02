-- import lspconfig plugin safely
local lspconfig_status, lspconfig = pcall(require, "lspconfig")
if not lspconfig_status then
	return
end
local util = require("lspconfig.util")

-- import cmp-nvim-lsp plugin safely
local cmp_nvim_lsp_status, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if not cmp_nvim_lsp_status then
	return
end

-- import typescript plugin safely
local typescript_setup, typescript = pcall(require, "typescript")
if not typescript_setup then
	return
end

local keymap = vim.keymap -- for conciseness

-- enable keybinds only for when lsp server available
local on_attach = function(client, bufnr)
	-- keybind options
	local opts = { noremap = true, silent = true, buffer = bufnr }

	-- set keybinds
	keymap.set("n", "gr", "<cmd>Lspsaga finder<CR>", opts) -- show definition, references
	-- keymap.set("n", "gD", "<Cmd>lua vim.lsp.buf.declaration()<CR>", opts) -- got to declaration
	keymap.set("n", "gD", "<cmd>Lspsaga peek_definition<CR>", opts)      -- see definition and make edits in window
	keymap.set("n", "gd", "<cmd>Lspsaga goto_definition<CR>", opts) -- see definition and make edits in window
	keymap.set("n", "gt", "<cmd>Lspsaga peek_type_definition<CR>", opts) -- see definition and make edits in window
	keymap.set("n", "<leader>kk", "<cmd>Lspsaga peek_type_definition<CR>", opts) -- see definition and make edits in window
	keymap.set("n", "<leader>K", "<cmd>Lspsaga hover_doc<CR>", opts) -- show documentation for what is under cursor
	-- keymap.set("n", "gt", "<cmd>Lspsaga goto_type_definition<CR>", opts) -- see definition and make edits in window

	keymap.set("n", "<leader>sl", "<cmd>Lspsaga show_line_diagnostics<CR>", opts)

	-- Like show_line_diagnostics, it supports passing the ++unfocus argument
	keymap.set("n", "<leader>sc", "<cmd>Lspsaga show_cursor_diagnostics<CR>", opts)

	-- Show buffer diagnostics
	keymap.set("n", "<leader>sb", "<cmd>Lspsaga show_buf_diagnostics<CR>", opts)

	keymap.set("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts) -- go to implementation
	keymap.set("n", "<leader>ca", "<cmd>Lspsaga code_action<CR>", opts) -- see available code actions
	keymap.set("n", "da", "<cmd>Lspsaga code_action<CR>", opts) -- see available code actions
	keymap.set("n", "<leader>rn", "<cmd>Lspsaga rename<CR>", opts) -- smart rename
	keymap.set("n", "<leader>dd", "<cmd>Lspsaga show_line_diagnostics<CR>", opts) -- show  diagnostics for line
	keymap.set("n", "<leader>dD", "<cmd>Lspsaga show_cursor_diagnostics<CR>", opts) -- show diagnostics for cursor
	keymap.set("n", "dp", "<cmd>Lspsaga diagnostic_jump_prev<CR>", opts) -- jump to previous diagnostic in buffer
	keymap.set("n", "dn", "<cmd>Lspsaga diagnostic_jump_next<CR>", opts) -- jump to next diagnostic in buffer
	keymap.set("n", "<leader>o", "<cmd>LSoutlineToggle<CR>", opts) -- see outline on right hand side

	-- typescript specific keymaps (e.g. rename file and update imports)
	if client.name == "tsserver" then
		keymap.set("n", "<leader>rf", ":TypescriptRenameFile<CR>") -- rename file and update imports
		keymap.set("n", "<leader>oi", ":TypescriptOrganizeImports<CR>") -- organize imports (not in youtube nvim video)
		keymap.set("n", "<leader>ru", ":TypescriptRemoveUnused<CR>") -- remove unused variables (not in youtube nvim video)
	end
end

-- used to enable autocompletion (assign to every lsp server config)
local capabilities = cmp_nvim_lsp.default_capabilities()

local servers = { "tsserver", "cssls", "emmet_language_server", "html", "lua_ls", "phpactor" }

for _, lsp in ipairs(servers) do
	lspconfig[lsp].setup({
		on_attach = on_attach,
		capabilities = capabilities,
		-- cmd = {"tsserver", "phpactor", "--completion-styled=detailed"}
	})
end

lspconfig.phpactor.setup({
	on_attach = on_attach,
	capabilities = capabilities,
	init_options = {
		["language_server_phpstan.enabled"] = false,
		["language_server_psalm.enabled"] = false,
	},
	cmd = { "phpactor", "language-server" },
	root_dir = function(pattern)
		local cwd = vim.loop.cwd()
		local root = util.root_pattern("composer.json", ".git")(pattern)

		-- prefer cwd if root is a descendant
		return util.path.is_descendant(cwd, root) and cwd or root
	end,
})

typescript.setup({
	server = {
		capabilities = capabilities,
		on_attach = on_attach,
	},
})

vim.api.nvim_create_autocmd({ "FileType" }, {
	pattern = "astro,css,eruby,html,htmldjango,javascriptreact,less,pug,sass,scss,svelte,typescriptreact,vue",
	callback = function()
		vim.lsp.start({
			cmd = { "emmet-language-server", "--stdio" },
			root_dir = vim.fs.dirname(vim.fs.find({ ".git" }, { upward = true })[1]),
			init_options = {
				--- @type table<string, any> https://docs.emmet.io/customization/preferences/
				preferences = {},
				--- @type "always" | "never" Defaults to `"always"`
				showExpandedAbbreviation = "always",
				--- @type boolean Defaults to `true`
				showAbbreviationSuggestions = true,
				--- @type boolean Defaults to `false`
				showSuggestionsAsSnippets = false,
				--- @type table<string, any> https://docs.emmet.io/customization/syntax-profiles/
				syntaxProfiles = {},
				--- @type table<string, string> https://docs.emmet.io/customization/snippets/#variables
				variables = {},
				--- @type string[]
				excludeLanguages = {},
			},
		})
	end,
})
