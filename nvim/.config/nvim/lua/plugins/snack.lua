return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	---@type snacks.Config
	opts = {
		bigfile = { enabled = true },
		notifier = {
			enabled = true,
			timeout = 3000,
			margin = {
				top = 2,
			},
		},
		image = {
			force = false,
			wo = {
				wrap = false,
				number = false,
				relativenumber = false,
				cursorcolumn = false,
				signcolumn = "no",
				foldcolumn = "0",
				list = false,
				spell = false,
				statuscolumn = "",
			},
		},
		explorer = {
			replace_netrw = true,
		},
		picker = {
			matcher = {
				fuzzy = true, -- use fuzzy matching
				smartcase = true, -- use smartcase
				ignorecase = true, -- use ignorecase
				sort_empty = false, -- sort results when the search string is empty
				filename_bonus = true, -- give bonus for matching file names (last part of the path)
				file_pos = true, -- support patterns like `file:line:col` and `file:line`
				-- the bonusses below, possibly require string concatenation and path normalization,
				-- so this can have a performance impact for large lists and increase memory usage
				cwd_bonus = true, -- give bonus for matching files in the cwd
				frecency = true, -- frecency bonus
				history_bonus = true, -- give more weight to chronological order
			},
			layout = {
				preset = "ivy",
				layout = {
					height = 0.5,
				},
			},
			formatters = {
				file = {
					truncate = 80,
				},
			},
			sources = {
				explorer = {
					auto_close = false,
					hidden = true,
					ignored = true,
				},
			},
		},
		notification_history = {
			enabled = true,
			border = "rounded",
			zindex = 100,
			width = 0.6,
			height = 0.6,
			minimal = false,
			title = " Notification History ",
			title_pos = "center",
			ft = "markdown",
			bo = { filetype = "snacks_notif_history", modifiable = false },
			wo = { winhighlight = "Normal:SnacksNotifierHistory" },
			keys = { q = "close" },
		},
		dashboard = {
			enabled = true,
			sections = {
				{
					section = "header",
				},
				{ icon = " ", title = "Keymaps", section = "keys", indent = 2, padding = 1 },
				{ icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
				{ icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
				{
					icon = " ",
					title = "Git Status",
					section = "terminal",
					enabled = function()
						return Snacks.git.get_root() ~= nil
					end,
					cmd = "hub status --short --branch --renames",
					height = 5,
					padding = 1,
					ttl = 5 * 60,
					indent = 3,
				},
				{ section = "startup" },
			},
		},
		quickfile = { enabled = true },
		statuscolumn = {
			left = { "mark", "sign" },
			right = { "fold", "git" },
			folds = {
				open = "false",
				git_hl = "false",
			},
			git = {
				pattern = { "GitSigns", "MiniDiffSign" },
			},
			refresh = 100,
		},
		words = {
			debounce = 200,
			notify_end = true,
			notify_jump = false,
			foldopen = true,
			jumplist = true,
			modes = { "n", "i", "c" },
		},
		scroll = {
			enabled = false,
			--- @diagnostic disable-next-line: missing-fields
			animate = {
				duration = { step = 15, total = 250 },
				easing = "linear",
			},
			spamming = 10, -- threshold for spamming detection
			-- what buffers to animate
			filter = function(buf)
				return vim.g.snacks_scroll ~= false
					and vim.b[buf].snacks_scroll ~= false
					and vim.bo[buf].buftype ~= "terminal"
			end,
		},
		indent = {
			enabled = true,
			indent = {
				priority = 1,
				enabled = true, -- enable indent guides
				char = "│",
				only_scope = false, -- only show indent guides of the scope
				only_current = false, -- only show indent guides in the current window
				hl = "SnacksIndent", ---@type string|string[] hl groups for indent guides
			},
			chunk = {
				enabled = true,
				only_current = true,
				priority = 200,
				hl = "SnacksIndentChunk", ---@type string|string[] hl group for chunk scopes
				char = {
					corner_top = "╭",
					corner_bottom = "╰",
					horizontal = "─",
					vertical = "│",
					arrow = "",
				},
			},
			filter = function(buf)
				return vim.g.snacks_indent ~= false and vim.b[buf].snacks_indent ~= false and vim.bo[buf].buftype == ""
			end,
		},
		input = { enabled = true },
		styles = {
			---@diagnostic disable-next-line: missing-fields
			notification = {
				border = "rounded",
				zindex = 100,
				ft = "markdown",
				wo = {
					winblend = 5,
					wrap = false,
					conceallevel = 2,
					colorcolumn = "",
				},
				bo = {
					filetype = "snacks_notif",
				},
			},
		},
		terminal = {
			bo = {
				filetype = "snacks_terminal",
			},
			wo = {},
			---@class snacks.terminal.Config
			---@field override? fun(cmd?: string|string[], opts?: snacks.terminal.Opts) Use this to use a different terminal implementation
			{
				win = { style = "terminal" },
			},
			keys = {
				q = "hide",
				gf = function(self)
					local f = vim.fn.findfile(vim.fn.expand("<cfile>"), "**")
					if f == "" then
						Snacks.notify.warn("No file under cursor")
					else
						self:hide()
						vim.schedule(function()
							vim.cmd("e " .. f)
						end)
					end
				end,
				term_normal = {
					"<esc>",
					function(self)
						self.esc_timer = self.esc_timer or (vim.uv or vim.loop).new_timer()
						if self.esc_timer:is_active() then
							self.esc_timer:stop()
							vim.cmd("stopinsert")
						else
							self.esc_timer:start(200, 0, function() end)
							return "<esc>"
						end
					end,
					mode = "t",
					expr = true,
					desc = "Double escape to normal mode",
				},
			},
		},
	},
	keys = {
		{
			"<leader>e",
			function()
				Snacks.explorer()
			end,
			desc = "Snacks Explorer",
		},
		{
			"<leader><space>",
			function()
				Snacks.picker.files({ hidden = true, follow = true })
			end,
			desc = "Smart Picker",
		},
		{
			"<C-b>",
			function()
				Snacks.picker.buffers()
			end,
			desc = "Snacks Picker Buffers",
		},
		{
			"<leader>fw",
			function()
				Snacks.picker.grep({ hidden = true })
			end,
			mode = { "n" },
			desc = "Snacks Picker Word",
		},
		{
			"<leader>fw",
			function()
				Snacks.picker.grep_word({ hidden = true })
			end,
			mode = { "v" },
			desc = "Snacks Picker Word",
		},
		{
			"<leader>fs",
			function()
				Snacks.picker.grep_word({ hidden = true })
			end,
			mode = { "v" },
			desc = "Snacks Picker Word",
		},
		{
			"<leader>ff",
			function()
				Snacks.picker.smart()
			end,
			mode = { "n" },
			desc = "Smart Picker",
		},
		{
			"<leader>dl",
			function()
				Snacks.picker.diagnostics()
			end,
			mode = { "n" },
			desc = "Diagnostics Picker",
		},
		{
			"<leader>un",
			function()
				Snacks.notifier.hide()
			end,
			desc = "Dismiss All Notifications",
		},
		{
			"<leader>uh",
			function()
				Snacks.notifier.show_history()
			end,
		},
		{
			"<C-\\>",
			function()
				Snacks.terminal.toggle()
			end,
		},
		{
			"<leader>q",
			function()
				local answer = vim.fn.confirm("Close this buffer?", "&Yes\n&No", 1)
				if answer == 1 then
					Snacks.bufdelete()
				end
			end,
			desc = "Delete Buffer",
		},
		{
			"<leader>og",
			function()
				Snacks.lazygit()
			end,
			desc = "Lazygit",
		},
		{
			"<leader>ob",
			function()
				Snacks.gitbrowse()
			end,
			desc = "Git Browse",
		},
		{
			"<leader>gf",
			function()
				Snacks.lazygit.log_file()
			end,
			desc = "Lazygit Current File History",
		},
		{
			"<leader>gl",
			function()
				Snacks.lazygit.log()
			end,
			desc = "Lazygit Log (cwd)",
		},
		{
			"<leader>cR",
			function()
				Snacks.rename()
			end,
			desc = "Rename File",
		},
		{
			"]]",
			function()
				Snacks.words.jump(vim.v.count1)
			end,
			desc = "Next Reference",
			mode = { "n", "t" },
		},
		{
			"[[",
			function()
				Snacks.words.jump(-vim.v.count1)
			end,
			desc = "Prev Reference",
			mode = { "n", "t" },
		},
	},
	init = function()
		vim.g.snacks_animate = false
		-- Terminal Mappings
		vim.keymap.set("t", "<C-\\>", "<cmd>close<cr>", { desc = "Hide Terminal" })
		vim.api.nvim_create_autocmd("User", {
			pattern = "VeryLazy",
			callback = function()
				-- Setup some globals for debugging (lazy-loaded)
				_G.dd = function(...)
					Snacks.debug.inspect(...)
				end
				_G.bt = function()
					Snacks.debug.backtrace()
				end
				vim.print = _G.dd -- Override print to use snacks for `:=` command

				-- Create some toggle mappings
				Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
				Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
				Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
				Snacks.toggle.diagnostics():map("<leader>ud")
				Snacks.toggle.line_number():map("<leader>ul")
				Snacks.toggle
					.option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 })
					:map("<leader>uc")
				Snacks.toggle.treesitter():map("<leader>uT")
				Snacks.toggle
					.option("background", { off = "light", on = "dark", name = "Dark Background" })
					:map("<leader>ub")
				Snacks.toggle.inlay_hints():map("<leader>gI")
			end,
		})
		---@type table<number, {token:lsp.ProgressToken, msg:string, done:boolean}[]>
		local progress = vim.defaulttable()
		vim.api.nvim_create_autocmd("LspProgress", {
			---@param ev {data: {client_id: integer, params: lsp.ProgressParams}}
			callback = function(ev)
				local client = vim.lsp.get_client_by_id(ev.data.client_id)
				local value = ev.data.params.value --[[@as {percentage?: number, title?: string, message?: string, kind: "begin" | "report" | "end"}]]
				if not client or type(value) ~= "table" then
					return
				end
				local p = progress[client.id]

				for i = 1, #p + 1 do
					if i == #p + 1 or p[i].token == ev.data.params.token then
						p[i] = {
							token = ev.data.params.token,
							msg = ("[%3d%%] %s%s"):format(
								value.kind == "end" and 100 or value.percentage or 100,
								value.title or "",
								value.message and (" **%s**"):format(value.message) or ""
							),
							done = value.kind == "end",
						}
						break
					end
				end

				local msg = {} ---@type string[]
				progress[client.id] = vim.tbl_filter(function(v)
					return table.insert(msg, v.msg) or not v.done
				end, p)

				local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
				vim.notify(table.concat(msg, "\n"), "info", {
					id = "lsp_progress",
					title = client.name,
					opts = function(notif)
						notif.icon = #progress[client.id] == 0 and " "
							or spinner[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinner + 1]
					end,
				})
			end,
		})
	end,
}
