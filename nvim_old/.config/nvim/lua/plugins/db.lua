return {
	{
		"kristijanhusak/vim-dadbod-ui",
		dependencies = {
			{ "tpope/vim-dadbod", lazy = true },
			{ "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true }, -- Optional
		},
		cmd = {
			"DBUI",
			"DBUIToggle",
			"DBUIAddConnection",
			"DBUIFindBuffer",
		},
		keys = {
			{
				"<leader>db",
				"<cmd>DBUIToggle<cr>",
				desc = "DB UI",
			},
		},
		init = function()
			vim.g.db_ui_use_nerd_fonts = 1
			vim.g.dbs = {
				{
					name = "ERP - Local",
					url = "mariadb://dev:LangTech%40123@192.168.0.203:3306?ssl=false",
				},
				{
					name = "[Inertia] Admin",
					url = "sqlite:~/github/inertia-base/database/database.sqlite",
				},
				{
					name = "[Inertia] Note",
					url = "sqlite:~/github/inertia-base/database/app_notes.sqlite",
				},
			}
			vim.g.db_ui_table_helpers = {
				mariadb = {
					Count = "select count(*) from {table}",
					List = "select * from {dbname}.{table} limit 100;",
				},
			}
		end,
	},
}
