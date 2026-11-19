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
   → returns { qid, total, idsAvailable, fetched, digest[] }
     `digest` is one compact row per listing (life / fire / cold / lightning / chaos /
     phys / price / seller / armour). Full mod text stays in the page: 60 rows with mods
     is ~30KB and does not survive the trip back through the model.

3  node scripts/pool.mjs save --league <L> --slot <slot> --file /tmp/opencode/<slot>-rows.json
   → accepts the digest as-is (or full API rows), derives life/res, writes
     ~/pob/pool/<L>/<slot>.json

4  node scripts/pool.mjs show --league <L> --slot <slot> [--sort life] [--max-age 15]
   → the candidate table; exits 4 when the pool is stale

5  pick the candidates, then get their full mod text for the sim — paste this as a
   second browse.eval expression on the same tab (no request, the page already has it):
       window.__p.full([3, 12, 27])
   → returns [{ n, b, p, seller, m:[mods] }, …] ready to become items.json

6  node scripts/sim.mjs --build current.xml --items items.json --sets sets.json > /tmp/opencode/sim.js
   → emits a complete code-mode program (all sets, attribute check, res snapshot)

7  paste /tmp/opencode/sim.js into the `execute` tool
   → returns { own, reqs, base, <set>: {...} }

8  node scripts/table.mjs --pick <set> --file /tmp/opencode/sim-out.json
   → gates (caps, overcap >= 20, attributes) + the two report tables
```

The sim program and the sim output are both several KB. Getting them in and out of the
model is the slowest part of a run: keep item texts to the picks, and read the emitted
program as a file rather than re-typing it.

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
| `check.mjs` | contract lint: no run data in `SKILL.md`/`reference/*`/`scripts/*`, no single-listing specs |

`check.mjs` runs in the repo's pre-commit hook; run it by hand after editing the skill.

## Specs shipped

Specs are **reusable filter sets**, not run artifacts. A spec that pins one listing
exact rolls (`min === max`) is not reusable — write it to `/tmp/opencode` for the run
and leave it out of the repo; `check.mjs` rejects it.

| Spec | What it finds |
|---|---|
| `ring.json` | rare ring, life 90+, total elemental res 90+, ≤10c |
| `ring-chaos.json` | rare ring with chaos res 20+ and life 65+, ≤20c |
| `gloves-chaos-cold.json` | armour gloves, chaos 20+ / cold 25+ / life 80+, ≤20c |
| `belt-ryslatha.json` | the unique by name, ≤60c |
| `axe-cheap.json` | two-hand axe ≤10c, sorted by pDPS desc |

## What the digest gives you

One shape for every item class. Keys present for all items:

`n` name · `b` base · `p` price (chaos) · `seller` · `q` quality · `ilvl` · `soc` sockets ·
`st` stack size · `cor` corrupted · `x` any property not listed below (flask charges,
gem lines, weapon range...) · `life` / `fire` / `cold` / `lightning` / `chaos` resistances ·
`phys` the `Adds X to Y Physical Damage` roll as text.

Class-specific, non-zero only when the item has them:

`ar` armour · `ev` evasion · `es` energy shield · `pdps` physical DPS ·
`edps` elemental DPS · `aps` attacks per second · `crit` crit chance · `pdmg` / `edmg`
the raw damage ranges.

`pool.mjs show` picks its columns from the pool: a pool with any `pdps` prints the weapon
table, otherwise the armour/ring table. Sort with `--sort pdps` (weapons) or `--sort life`.

## Retrying without spending a search

```
node scripts/search.mjs --league <L> --slot <slot> --spec <spec> --reuse
```

Emits the same expression minus the search POST: it re-reads `window.__p.ids` already in
the tab and re-fetches. Use it when the mapping failed, the digest needs a new field, or
you want the full mod text again. It skips the spacing/burst gates because it is not a
search. `--reuse` fails cleanly if the tab holds no stored query.

## Adding a slot

Write `specs/<slot>.json` (same shape as the existing ones: `status`, `filters`, `stats`,
`sort`), then run `search.mjs` with the spec. A spec with `"term"` searches by unique
name; leave `term` out and filter by stat ids when the item is a rare.
