local keymap = vim.keymap
local opt = {
	highlight = {
		backdrop = true,
	},
	label = {
		after = false,
		style = "overlay",
	},
}
local charOpt = {
	modes = {
		char = {
			jump_labels = true,
		},
	},
}
-- flash
keymap.set({ "n", "o", "x" }, "s", function()
	require("flash").jump()
end)
keymap.set({ "n", "o", "x" }, "S", function()
	require("flash").treesitter(opt)
end)
keymap.set({ "n", "o", "x" }, "f", function()
	require("flash").jump(charOpt)
end)
keymap.set({ "n", "o", "x" }, "F", function()
	require("flash").jump(charOpt)
end)
