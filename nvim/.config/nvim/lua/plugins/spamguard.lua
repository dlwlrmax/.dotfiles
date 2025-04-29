if true then return {} end
return {
	"timseriakov/spamguard.nvim",
	config = function()
		require("spamguard").setup({
			keys = {
				j = { threshold = 6, suggestion = "use s or f instead of spamming jjjj 😎" },
				k = { threshold = 6, suggestion = "use s or F instead of spamming kkkk 😎" },
				h = { threshold = 8, suggestion = "use 10h or b / ge 😎" },
				l = { threshold = 8, suggestion = "try w or e — it's faster! 😎" },
				w = { threshold = 10, suggestion = "use s or f — more precise and quicker! 😎" },
			},
		})
	end,
}
