local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

ls.snippets = {
  lua = {
    ls.parser.parse_snippet("func", "function ${1:name}(${2:args})\n\t${0}\nend"),
  },
}
