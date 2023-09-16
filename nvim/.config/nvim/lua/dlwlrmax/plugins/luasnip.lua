local setup, ls = pcall(require, "luasnip")
if not setup then
  return
end

local type = require "luasnip.util.types"

ls.config.set_config {
  history = true,
  updateevents = "TextChanged,TextChangedI",
  enable_autosnippets = true,
}
ls.snippets = {
  all = {
    -- avaiable in any files
  },
  lua = {
    ls.parser.parse_snippet("lf", "local $1 = function($2)\n $0 \nend")
  }
}
