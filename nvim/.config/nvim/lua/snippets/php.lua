local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

ls.add_snippet({
	trig = "php",
	desc = "php",
	dscr = "php",
	wordTrig = true,
	expanded = s({ t("<?php\n"), i(1), t("\n?>") }),
	m = "php",
})

ls.add_snippet({
	trig = "phpf",
	desc = "phpf",
	dscr = "phpf",
	wordTrig = true,
	expanded = s({ t("<?php\nfunction "), i(1), t("() {\n\t"), i(2), t("\n}\n?>") }),
	m = "php",
})

ls.add_snippet({
	trig = "phpc",
	desc = "phpc",
	dscr = "phpc",
	wordTrig = true,
	expanded = s({ t("<?php\n"), i(1), t("\n?>") }),
	m = "php",
})

ls.add_snippet({
	trig = "phpif",
	desc = "phpif",
	dscr = "phpif",
	wordTrig = true,
	expanded = s({ t("<?php\nif ("), i(1), t(") {\n\t"), i(2), t("\n}\n?>") }),
	m = "php",
})

ls.add_snippet({
	trig = "phpifelse",
	desc = "phpifelse",
	dscr = "phpifelse",
	wordTrig = true,
	expanded = s({ t("<?php\nif ("), i(1), t(") {\n\t"), i(2), t("\n} else {\n\t"), i(3), t("\n}\n?>") }),
	m = "php",
})

ls.add_snippet({
	trig = "epre",
	desc = "echo <pre>{}<pre>",
	dscr = "echo <pre>{}<pre>",
	wordTrig = true,
	expanded = s({ t('echo "<pre>'), i(1), t('</pre>";') }),
    m = "php"
})
