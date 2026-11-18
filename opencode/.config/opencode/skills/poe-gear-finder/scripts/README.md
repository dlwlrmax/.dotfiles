# Scripts — the mechanics, not the prose

The rules in `SKILL.md` describe *what* must hold. These scripts are *how* it is done,
so a run never re-derives the code (hand-written inline JS is where escaping bugs and
rate-limit bursts came from).

Everything is plain Node, no dependencies. Scratch files go in `/tmp/opencode`.

## Pipeline

```
1  node scripts/search.mjs --league <L> --slot <slot> --spec specs/<spec>.json
   → enforces >=10s since the last search and the 4-searches-per-30min cap
   → prints a ready-to-paste `expression` for tools.browse.eval (60 ids fetched)

2  paste that expression into tools.browse.eval on an open trade tab
   → returns { qid, total, fetched, rows[] }

3  node scripts/pool.mjs save --league <L> --slot <slot> --file /tmp/opencode/<slot>-rows.json
   → normalises mods, derives life/res, writes ~/pob/pool/<L>/<slot>.json

4  node scripts/pool.mjs show --league <L> --slot <slot> [--sort life] [--max-age 15]
   → the candidate table; exits 4 when the pool is stale

5  node scripts/sim.mjs --build current.xml --items items.json --sets sets.json > /tmp/opencode/sim.js
   → emits a complete code-mode program (all sets, attribute check, res snapshot)

6  paste /tmp/opencode/sim.js into the `execute` tool
   → returns { own, reqs, base, <set>: {...} }

7  node scripts/table.mjs --pick <set> --file /tmp/opencode/sim-out.json
   → gates (caps, overcap >= 20, attributes) + the two report tables
```

## Rules the scripts enforce mechanically

- **Spacing**: `search.mjs` refuses to run less than 10 s after the previous search
  (`~/pob/pool/<L>/.lastsearch`). `--force` overrides, deliberately.
- **Burst cap**: more than 4 searches in 30 min is refused (`~/pob/pool/<L>/.searchlog`).
- **Freshness**: `pool.mjs show` exits 4 on a pool older than `--max-age` (default
  15 min), so a stale price never reaches the user.
- **Attribute requirements**: `sim.mjs` bakes the `parse_item` check into the program,
  so an unwearable item shows up as a FAIL instead of a healthy looking stat delta.

## Files

| File | Role |
|---|---|
| `search.mjs` | spec → browser expression + spacing/burst gates |
| `pool.mjs` | save/show/list + freshness gate; the only place rows are parsed |
| `sim.mjs` | items + sets → code-mode PoB program with attribute checks |
| `table.mjs` | sim output → gates + markdown report tables |
| `../specs/*.json` | trade filter specs passed to `search.mjs` |

## Adding a slot

Write `specs/<slot>.json` (same shape as the existing ones: `status`, `filters`, `stats`,
`sort`), then run `search.mjs` with the spec. A spec with `"term"` searches by unique
name; leave `term` out and filter by stat ids when the item is a rare.
