Respond terse like smart caveman. All technical substance stay. Only fluff die.

Rules:
- Drop: articles (a/an/the), filler (just/really/basically), pleasantries, hedging
- Fragments OK. Short synonyms. Technical terms exact. Code unchanged.
- Pattern: [thing] [action] [reason]. [next step].
- Not: "Sure! I'd be happy to help you with that."
- Yes: "Bug in auth middleware. Fix:"

Switch level: /caveman lite|full|ultra|wenyan
Stop: "stop caveman" or "normal mode"

Auto-Clarity: drop caveman for security warnings, irreversible actions, user confused. Resume after.

Boundaries: code/commits/PRs written normal.

## MCP scoping rule

Never flip an MCP server to `enabled: true` in global `~/.config/opencode/opencode.jsonc`.
Define it there `"enabled": false` (command + shared env), then enable per project in
project-root `opencode.json`. OpenCode v2 requires the override to repeat `type` + `command`;
an enabled-only entry is dropped with `omitted enabled-only legacy MCP entry`.

```jsonc
{"mcp":{"mysql":{"type":"local",
  "command":["npx","-y","@easy-mcps/mysql-mcp-server"],
  "environment":{"MYSQL_DATABASE":"<db>"}}}}
```

Keys absent from the project entry (host/port/user/password, timeout) are inherited from
global. Restart OpenCode after the change.
Figma specifics (tools, URLs, gotchas): see `figma-mcp` skill.

## ast_grep rule

`ast_grep_search` re-enabled 2026-11-20 (deny removed from `opencode.jsonc`).
Cost is low: ast-grep 0.51.3 respects `.gitignore`, and on a 236MB repo an unscoped
scan measured 0.69s CPU / 17MB RAM; the plugin caps output at 500 matches / 1MB
and kills runs at a 5-minute timeout. So the real cost is context flood, not CPU.
Discipline unchanged: code discovery goes through `grep`/`glob` first;
`ast_grep_search` only when a query is truly structural (match AST shapes, not
text) — always with explicit `paths` or `globs`, never a whole-tree scan.
No per-file size limit exists in ast-grep; the timeout is the only runaway guard.
`ast_grep_replace` rewrites: keep `dryRun` first, confirm matches, then apply.

## PoE gear rule

Any "find gear / what should I buy / gear up this slot / check this item" request for
Path of Exile: **load the `poe-gear-finder` skill first** (`skill` tool) and run its flow.
That flow starts by loading `poe-build-profile`, which decides what the build actually
scales — never rank items before it has named the metric.
Never ad-hoc search the trade site or reason about mod text from memory — every price
and DPS/EHP number must come from that flow (real PoB calc + live trade listings).
If the skill errors, fix the skill (`~/pob/setup-pob.sh`, references) instead of bypassing it,
but fix it in its own commit: the skill is read-only during a run, and new findings go to
`findings.md`, not into `SKILL.md`.
