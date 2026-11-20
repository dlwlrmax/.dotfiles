---
name: poe-gear-finder
description: Find and verify Path of Exile 1 gear upgrades on a budget using the real Path of Building engine. Use when the user asks to gear up a character, find an upgrade for a slot (helmet, rings, weapon, flask...), shop within a chaos/divine budget, compare trade listings by actual DPS/EHP impact, or asks "what should I buy next" for a PoE build.
---

# PoE gear finder (headless PoB + live trade)

Every candidate is **equipped in the build and recalculated by PoB** — never judged
from mod text. Whole run is ~90s; see *Speed rules* for why and how.

References: `reference/trade-api.md` (query shapes, stat ids, rate limits),
`reference/pob-sim.md` (simulation recipe), `scripts/README.md` (the runners),
`specs/*.json` (trade filter specs), `findings.md` (evidence log).

## This file is a contract; `findings.md` is the local notebook

`SKILL.md` and `reference/*` change only when a **rule** changes — something that would
have changed an answer. Prices, sellers, item names and "what I measured last run" go in
`findings.md`: an append-only log, read for context, **never** read as instructions.
**The notebook is per-machine scratch, not tracked in git** — never commit, push, or
otherwise ship it; the durable knowledge travels as promoted rules in the contract, not
as log entries.

The skill is **read-only during a run**:

- Do not edit `SKILL.md`, `reference/*` or `scripts/*` while working a request.
- Something missing or awkward? Append one line under *Friction* in `findings.md` and
  finish with the tools that exist.
- A runner broken badly enough to stop the run is the one exception: fix it minimally,
  append the `Friction:` line, and commit that fix **alone**
  (`pob skill: fix …`) — never bundled with a gear answer.
- Patch the contract afterwards, once, and only for a rule that cost an answer.

`node scripts/check.mjs` (run by the repo's pre-commit hook) rejects run data leaking
into the contract files: account handles, prices, dates, and references to the run.

## Definition of done — re-read this before sending the final message

A run is not finished until the answer contains, in this order:

1. **Buy list, scarcest first** — per item: name · base · price · **seller account** ·
   tab/link · **listing count** for that filter.
2. **Stat table** (price | item | base | req | Δlife | ΔEHP | Δarmour | overcap F/C/L |
   Δchaos | ΔDPS).
3. **Res before/after table** — total / cap / overcap for fire, cold, lightning, chaos.
4. **Budget line** — spent / budget / left.
5. **Alternatives** — the pick **plus 2-3 rejected sets**, each labelled with the axis it
   differs on (cheaper / more res / more DPS / more chaos), so the user can trade off.
6. **Nothing raw.** Tool JSON, item text and `eval` output never appear in the answer —
   everything goes through the tables above.

Then stop. Do not run another search to "improve" an answer the user has not asked to
change, and do not re-verify a listing you already handed over unless asked.


## Ask once, at the start (one message)

1. Build: import code / XML / pobb.in link.
2. Budget: amount + currency.
3. Slots: which ones (default: ask, do not assume all).
4. Base preference: **armour / evasion / ES / any** — this changes every search.
5. Priority order: life → elemental res overcap → chaos res → DPS, unless they say otherwise.

Never re-ask mid-run because a filter returned nothing — relax filters instead
(drop the rarest requirement first, tell them what you dropped).

## Flow

Runner: `scripts/*.mjs` + `specs/*.json` — see `scripts/README.md`. **Do not hand-write
the browser or PoB code**: JS typed inline is where the escaping bugs and the
rate-limit bursts came from. The scripts also enforce the spacing, burst and
freshness gates for you.

0. **Profile the build first** — load the `poe-build-profile` skill and run its runner by
   absolute path, `node ~/.config/opencode/skills/poe-build-profile/scripts/profile.mjs
   --build <name.xml>` (`profile.mjs` lives in that sibling skill, not in this one's
   `scripts/`). It returns the archetype, the metric
   that ranks this build, the support audit and the defects (unreserved mana, life,
   chaos res, missing curse) **before** any search. Every comparison below inherits that
   metric: a bleed build is ranked by `BleedDPS` + `AverageDamage`, and ranking it by
   pDPS hands the user a worse item with a bigger number on it. Its defects outrank any
   gear purchase — do not shop damage around a build that cannot cast its skills.

1. **Load the build** — `lua_load_build({build_name})` (cache the XML under
   `~/pob/builds/`) or `lua_import_code({code})`. The load reply carries
   life/DPS/EHP/resistances. If the PoB MCP errors, **stop and fix the tool**
   (`~/pob/setup-pob.sh`, then the references) — never fall back to judging mods by eye
   or to a trade-only answer with no PoB numbers.
2. **Baseline** — captured for you: the sim program returns `base` next to every
   candidate set, and `table.mjs` diffs against it. Two keys matter, both from
   `export_full_stats({filter: "Resist"})`: `*ResistOverCap` (how far above the cap) and
   `Missing<Element>Resist` (**0 means capped**; anything else is how much you are short).
   Never judge capping from `lua_get_stats` — its `FireResist` is **clamped to the cap**, so
   a build 1% short prints `76 / 76` and looks capped. The res before/after table is
   mandatory output, not an optional extra.
3. **Search** — `node scripts/search.mjs --league <L> --slot <slot> --spec specs/<spec>.json`.
   Shipped specs are `axe-cheap`, `belt-ryslatha`, `gloves-chaos-cold`, `ring-chaos`,
   `ring` and `helm` (see the spec table in `scripts/README.md`); `--spec` takes the
   spec's file name, which is not always the slot.
   It enforces the search spacing and burst gates from `reference/trade-api.md`, then
   prints the `expression` to paste into `browse.eval` — it is eval-wrapped, paste it
   verbatim and unwrap the double-encoded result (recipe in `reference/trade-api.md`).
   Rank the returned digest with `window.__p.top(<n>, "<key>")` (no code), then pull
   full mod text for the few picks with a second expression, `window.__p.full([i,j,k])` —
   no extra request — and use that to build `items.json`. **Extract picks immediately**:
   in-page state (`window.__p`) dies with the tab. `pool.mjs save` persists the digest
   for cross-session resume; while the run continues in the same session it is optional
   (the eval result reaches the model, not the disk — write the file only when the
   session might end before the report).
   Re-reading the ids already in the open tab is `search.mjs --reuse` — a fetch, not a
   search; that is the retry path after a mapping bug or a closed tab, and it costs
   no search request.
   The expression returns a compact **digest** (60 rows with full mod text is ~30KB and
   will not survive the trip back); the full mod text stays in the page, so pull it for
   the few picks with a second expression, `window.__p.full([i,j,k])` — no extra request —
   and use that to build `items.json`.
   **Shopping for the best under a cap, not the cheapest?** Encode a minimum on the
   ranking stat (armour, life, res) in the spec and ratchet it against the pool `total` —
   the quality ratchet under *Speed rules* owns that loop. Keep `sort: price asc`: the
   fetched slice is then the cheapest of the qualified, and the metric ranking happens
   client-side.
4. **Simulate** — `node scripts/sim.mjs --items <items.json> --sets <sets.json> > /tmp/opencode/sim.js`,
   then paste that program into the code-mode `execute` tool. It reloads the build per
   set, snapshots stats and resistances, and returns the attribute check. See
   `reference/pob-sim.md` for why each rule exists.
5. **Attribute check, every candidate** — mandatory, and already baked into the program:
   an item needing more `str/dex/int` than the build has shows as FAIL. PoB still applies
   the stats when a requirement is unmet (it only prints a build issue), so a green
   Life/DPS delta does **not** mean the item is wearable.
6. **Report** — `node scripts/table.mjs --pick <set> --file <sim output>` renders the
   gates (caps, overcap ≥ 20, attributes — flagged per set) plus both tables. Add the buy
   list from `pool.mjs show`. Satisfy the Definition of done at the top of this file.

## Res before / after (always print, every run)

One snapshot of the equipped build, one of the final set, same `snap()` for both.
Never quote a single number — res is where a swap silently breaks a build.

| Res | Before total / cap / overcap | After total / cap / overcap | Δ overcap |
|---|---|---|---|
| Fire | 108 / 75 / **+33** | 120 / 75 / **+45** | +12 |
| Cold | 124 / 75 / **+49** | 98 / 75 / **+23** | −26 |
| Lightning | 94 / 75 / **+19** | 142 / 75 / **+67** | +48 |
| Chaos | −37 / — / — | −60 / — / — | −23 |

Rules for that table:

- Print **total, cap and overcap** per element — overcap alone hides whether the
  build was even capped before (chaos is often negative and has no overcap).
- `overcap: 0` means **at or below cap**, not "fine". Chaos has no tracked cap or
  overcap in the sim output — its cells print dashes and the total is the number that
  matters.
- Flag any element that **drops** below +20 overcap, and say which item change
  caused it (the replaced item's mods are the reason — check the XML, don't guess).
- Flag any element that moves at all, even upward: a huge lightning gain usually
  means another element got starved by the same swap.
- If the user's priority did not include chaos, still print the row — it is
  informational, not a filter.

## Targets to encode as filters

- Life: `+# to maximum Life` min ≈ 1.2 × level (100+ at 84).
- Elemental res: aim **overcap ≥ 20%** per element; filter the element the build is
  thinnest on, not "total resistance" (total hides a hole in one element).
- Chaos res: only if the user says it matters.
- Armour builds: `armour_filters: {filters: {ar: {min: 300}}}` for helm,
  `ar: {min: 200}` for gloves; pick armour bases (Burgonet, Gauntlets, Plate).
- Attribute ownership: armour bases are also the cheapest way to satisfy
  requirements — a Lion Pelt wants 120 Dex and a Hubris Circlet 154 Int, which a
  Str-stacked melee build cannot wear. Check the numbers before recommending.
- Bleed chance is **not** a filter. If `export_full_stats({filter: "Bleed"})` shows
  `BleedChance: 100`, more bleed chance is worth nothing — check the number, never filter
  on it.
- Bleed: the DPS lever is **damage per hit**, not pDPS and not attack speed. Bleed does
  not stack — each application takes that hit's damage — so a slow, hard-hitting base
  beats a faster one with higher pDPS for the same mods. Use pDPS only to *find* a pool,
  then read the mods and simulate; the ranking inverts often enough that sorting by pDPS
  and buying the top row is a wrong answer.
- The mods that pay on a bleed weapon are `#% increased Physical Damage`, flat
  `Adds # to # Physical Damage`, `+#% to (Physical )Damage over Time Multiplier`
  (including the `for Bleeding` variant) and `Bleeding you inflict deals Damage #% Faster`.
  Read the number from the sim, not from mod text — a "faster bleeding" roll is worth more
  than pDPS suggests, and elemental added damage is dead weight next to Brutality.
- Cheap uniques are worth checking before rares, including league-variant bases with a
  large local `increased Physical Damage`: search the unique by name under the same price
  cap before assuming a rare wins. Both directions have failed a run — check, don't assume.
- Sort order and the measured deltas behind these rules are in `findings.md`.

## Speed rules (the whole point)

Rate limits are the scarce resource, fetches are cheap. **Numbers live in
`reference/trade-api.md` only** — that file is the single source of truth; do not
restate limits here (two copies drift into contradiction).

- **One search per slot, per run. Hard cap: 4 searches per run.** A re-search to
  "confirm" a listing is the biggest time sink and the main way to trip the limit.
  To iterate on candidates, re-`fetch` by id (cheap) — never re-search.
  More slots than the cap allows? Slots defer in the profile's defect-severity order
  (life, then thinnest resistance, then chaos, then damage), and the report names the
  deferred slots so the next run can start on them.
- **Space the searches out; never batch them.** search.mjs enforces the spacing and burst
  gates mechanically, and the numbers are in `reference/trade-api.md`. Never bypass them
  with `--force` for convenience: a run whose paste was aborted can be unmarked with
  `search.mjs --unmark` and retried inside the gates instead. Fetches may run
  back-to-back.
- **Re-navigating a stored `qid` URL costs a search request.** The query id is not a
  cache: loading `trade/search/<league>/<qid>` re-runs the search server-side. Read the
  tab that is already open; navigate only when you mean to spend a search.
- **Search returns 0 rows?** The filter was too strict, or the listing sold. Relax the
  rarest requirement and re-search — a legitimate re-search, and you
  must tell the user what you dropped.
- **Best under a cap is a ratchet, not a sort.** The search API hands back only the
  first ~100 ids by sort order and has no armour/pDPS-style sort key, so a price-asc
  pool always shows its cheapest slice — the metric-best listings sit deeper, where no
  fetch can reach. When the brief is "best X under budget", put a MINIMUM on the ranking
  stat in the spec and use each search's `total` as a free probe: a pool in the hundreds
  means the top is still unseen — raise the stat floor and re-search until the pool
  fits one fetch (~100 ids), then rank client-side from the digest and simulate the top.
  Those ratchet steps are legitimate re-searches, but they share the 4-search cap: if the
  brief says "don't care about price", start the floor high on the first query, and if
  the cap runs out mid-ratchet, report the deepest slice reached instead of forcing more.
- **Fetch long lists — 40+ ids, not the top 8.** Price-ascending top 8 routinely misses
  better items. Paginate in chunks of 10 before judging anything.
- **Travel to Hideout cannot be triggered by the agent.** The listing carries
  `hideout_token` and `fee`, but `POST /api/trade/whisper` refuses the naive payload
  (`403` bare, `400 Invalid query` with XHR headers; see *Travel to Hideout* in
  `reference/trade-api.md`). Do not probe it repeatedly: open the results page and let the
  user press the button. What you *can* do is report the `fee` and keep the tab alive.
- **Rare item names are not unique.** Ten different rares are called `Blood Loop`.
  A name-only tab is the reason the user "can't tell which one to buy". To hand over a
  listing unambiguously: use an **exact-roll filter** (`value: {min: N, max: N}` on the
  distinctive mods) to narrow the tab, and name the seller account next to it — the exact
  roll on its own still may not leave a single row.
- **Listings expire mid-run.** Before telling the user to buy, re-read the tab and
  confirm it still has rows and the same price. A cheap rare found two hours ago is usually
  gone — re-derive the candidate from live results instead of pinning to it.
- **Persist the pool to disk as you go**: `~/pob/pool/<League>/<slot>.json` with
  `{fetchedAt, slot, qid, total, idsAvailable, rows}`, TTL 15 minutes. Agent context is
  not storage — tab ids and in-page state (`window.__p`) die with the tab, and a closed
  tab must not cost a search.
- **One `execute` block per phase for the PoB side** (all simulations together, one
  reload per set). PoB import is ~7 s, re-`add_item` ~1 s; cache the XML, don't re-import.


## Report

`node scripts/table.mjs --pick <set> --file <sim output>` renders the gates and both
tables; the buy list comes from `pool.mjs show`. table.mjs renders the per-item table as
the `## Items (pick)` block (item · base · price · req · wear), and the full stat columns
(Δlife/ΔEHP/Δarmour/overcap F/C/L/Δchaos/ΔDPS) come from the Sets table deltas. Every item
handed over carries:
price · item · base · **req** · Δlife · ΔEHP · Δarmour · overcap F/C/L · Δchaos · ΔDPS.
Then the pick, the total spend vs budget, and what is left to upgrade.

### Buy order = scarcity order, not value order

Present **the hardest-to-replace item first**, not the cheapest or the biggest upgrade.
A player shopping over an hour will lose the rare listing long before the common one,
so the scarce item must be bought while it exists:

- Rank by **how many comparable listings exist** — the search `total` for that slot and
  filter set is the number to quote. A `total` of one is buy-it-now or lose-it; a total in
  the thousands can wait.
- Uniques with a specific roll, and rares needing several exact mods together (life +
  cold res + chaos res on gloves), are scarce. Armour helm with life + one res is not.
- Say the count next to each item so the user can see the risk, and put a whole-budget
  warning first if the sum exceeds it.

For **every** item handed over, give the buyer an unambiguous pointer — item name and
base are not enough (rare names repeat):

- the open tab, **plus** the seller account and the price, e.g.
  `helm tab · row 2 · <account> · <price>`;
- **API-driven tab with no rendered rows?** Hand over the qid URL
  (`https://www.pathofexile.com/trade/search/<league>/<qid>`) **plus** seller, price and
  the exact rolls — the buyer clicking it spends one deliberate search, which is theirs
  to spend at buy time. Rendering it yourself mid-run costs a search from the budget,
  so only navigate when you mean to;
- **highlight the row in the page** rather than describing where it is: outline it, insert
  a label with name/price/seller, `scrollIntoView`, then screenshot to confirm. Prose does
  not answer "which row do I buy" — one highlighted row does. The marks are cosmetic DOM
  injection and vanish on reload, so re-apply if the page refreshes;
- an exact-roll filter is **not** guaranteed unique either — combine it with the seller
  match to pin the row;
- and confirm the tab still has rows. "No results found" means the filter was too
  strict for that listing or it sold — rebuild the query, do not hand over an empty tab.

Never whisper or buy without explicit confirmation.
