# Prompt for home PC — paste into opencode there

```
Set up the Path of Exile gear-finder stack on this machine. Do it end to end, no
questions, and report what fails. Everything installs under ~/pob (no sudo, no
system packages beyond git/node/npm/luajit/gcc).

STEP 1 — write ~/pob/setup-pob.sh with exactly this content and chmod +x it:

#!/usr/bin/env bash
set -euo pipefail
POB_DIR="${POB_DIR:-$HOME/pob}"
POB_SRC="$POB_DIR/PathOfBuilding"
MCP_SRC="$POB_DIR/pob-mcp"
SQL="$POB_SRC/src"
RAW="https://raw.githubusercontent.com/PathOfBuildingCommunity/PathOfBuilding/dev"
mkdir -p "$POB_DIR"
for c in git node npm luajit gcc; do command -v "$c" >/dev/null || { echo "missing $c"; exit 1; }; done
[ -d /usr/include/luajit-2.1 ] || { echo "missing LuaJIT headers (/usr/include/luajit-2.1)"; exit 1; }
if [ -d "$POB_SRC/.git" ]; then git -C "$POB_SRC" pull --ff-only
else git clone --depth 1 --branch dev https://github.com/PathOfBuildingCommunity/PathOfBuilding.git "$POB_SRC"; fi
cd "$SQL"
mapfile -t HDR < <(grep -rl '^#@' --include='*.lua' . || true)
((${#HDR[@]})) && sed -i '1s/^#@/--@/' "${HDR[@]}"
mkdir -p lua
for f in xml.lua dkjson.lua base64.lua socket.lua sha2.lua lua-profiler.lua; do
  [ -s "lua/$f" ] || curl -fsSL -o "lua/$f" "$RAW/runtime/lua/$f"
done
if [ ! -d lua/sha1 ] || [ -z "$(ls -A lua/sha1 2>/dev/null)" ]; then
  for c in "$HOME/.local/share/RustyPathOfBuilding1/lua/sha1" "$HOME/.local/share/RustyPathOfBuilding2/lua/sha1"; do
    [ -d "$c" ] && { cp -r "$c" lua/sha1; break; }
  done
fi
cp -f lua/dkjson.lua . 2>/dev/null || true
if [ ! -f lua-utf8.so ]; then
  TMP=$(mktemp -d)
  git clone --depth 1 https://github.com/starwing/luautf8.git "$TMP/luautf8" >/dev/null 2>&1
  gcc -O2 -shared -fPIC -I/usr/include/luajit-2.1 -o lua-utf8.so "$TMP"/luautf8/*.c
  rm -rf "$TMP"
fi
if [ -d "$MCP_SRC/.git" ]; then git -C "$MCP_SRC" pull --ff-only
else git clone --depth 1 https://github.com/ianderse/pob-mcp.git "$MCP_SRC"; fi
cd "$MCP_SRC" && npm install --silent && npm run build
cd "$SQL" && LUA_PATH="./lua/?.lua;./lua/?/init.lua;;" timeout 300 luajit HeadlessWrapper.lua 2>&1 | tail -6

STEP 2 — run it: bash ~/pob/setup-pob.sh
  Expected success output ends with a PoB banner: "Loading passive tree data for
  version '3.3x'..." and "Startup time: N ms", with no Lua errors. If it fails on
  a `#@` header, a missing module, or `lua-utf8`, fix and re-run.

STEP 3 — write ~/pob/mcp-launch.sh (chmod +x):

#!/usr/bin/env bash
set -euo pipefail
POB_DIR="${POB_DIR:-$HOME/pob}"; SRC="$POB_DIR/PathOfBuilding/src"
export POB_LUA_ENABLED=true
export POB_CMD="${POB_CMD:-luajit}"
export POB_PATH="$SRC"
export POB_DIRECTORY="${POB_DIRECTORY:-${TMPDIR:-/tmp}/opencode/pob/builds}"
export LUA_PATH="$SRC/lua/?.lua;$SRC/lua/?/init.lua;./lua/?.lua;./lua/?/init.lua;;"
mkdir -p "$POB_DIRECTORY"
exec node "$POB_DIR/pob-mcp/build/index.js"

STEP 4 — add the MCP server to this project's opencode.json (create if absent,
merge into "mcp", keep existing keys). Rewrite `pob` to exactly:

{"mcp":{"pob":{"type":"local",
  "command":["node","{env:HOME}/pob/pob-mcp/build/index.js"],
  "environment":{
    "POB_LUA_ENABLED":"true",
    "POB_CMD":"luajit",
    "POB_PATH":"{env:HOME}/pob/PathOfBuilding/src",
    "POB_DIRECTORY":"{env:HOME}/pob/builds",
    "LUA_PATH":"{env:HOME}/pob/PathOfBuilding/src/lua/?.lua;{env:HOME}/pob/PathOfBuilding/src/lua/?/init.lua;./lua/?.lua;./lua/?/init.lua;;"}}}}

{env:HOME} interpolation is confirmed to work in both `command` and `environment`
— do not hardcode /home/<user>. Verify by calling pob.lua_start; it must answer
"PoB Lua Bridge started successfully." Do not use `bash -lc` in `command`; it
breaks MCP stdio registration.

STEP 5 — write the skill (15 files, exact content):

5a) ~/.config/opencode/skills/poe-gear-finder/SKILL.md

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

## This file is a contract; `findings.md` is the notebook

`SKILL.md` and `reference/*` change only when a **rule** changes — something that would
have changed an answer. Prices, sellers, item names and "what I measured last run" go in
`findings.md`: an append-only log, read for context, **never** read as instructions.

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
3. **Search** — `node scripts/search.mjs --league <L> --slot <slot> --spec specs/<slot>.json`.
   It refuses to run inside 10 s of the previous search and inside the 4-per-30-min cap,
   then prints the `expression` to paste into `browse.eval` (instant buyout, 60 ids
   fetched, so the pool is a pool). Save it with `node scripts/pool.mjs save …` and read
   candidates with `node scripts/pool.mjs show …`, which exits 4 on a stale pool.
   The expression returns a compact **digest** (60 rows with full mod text is ~30KB and
   will not survive the trip back); the full mod text stays in the page, so pull it for
   the few picks with a second expression, `window.__p.full([i,j,k])` — no extra request —
   and use that to build `items.json`.
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

| Res | Trước total / cap / overcap | Sau total / cap / overcap | Δ overcap |
|---|---|---|---|
| Fire | 111 / 78 / **+33** | 120 / 78 / **+42** | +9 |
| Cold | 124 / 77 / **+47** | 98 / 77 / **+21** | −26 |
| Lightning | 94 / 77 / **+17** | 142 / 77 / **+65** | +48 |
| Chaos | −37 / 75 / — | −60 / 75 / — | −23 |

Rules for that table:

- Print **total, cap and overcap** per element — overcap alone hides whether the
  build was even capped before (chaos is often negative and has no overcap).
- `overcap: 0` means **at or below cap**, not "fine". Chaos typically reads
  `total −37 / cap −37 / overcap 0`; the number that matters is the total.
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
- **Space searches ≥10 s apart. Never batch them.** Four slots = four searches, ten
  seconds apart. Fetches may run back-to-back inside that window.
- **Re-navigating a stored `qid` URL costs a search request.** The query id is not a
  cache: loading `trade/search/<league>/<qid>` re-runs the search server-side. Read the
  tab that is already open; navigate only when you mean to spend a search.
- **Search returns 0 rows?** The filter was too strict, or the listing sold. Relax the
  rarest requirement and re-search — that is the *one* legitimate re-search, and you
  must tell the user what you dropped.
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
  distinctive mods) so the tab shows one row, and name the seller account next to it.
- **Listings expire mid-run.** Before telling the user to buy, re-read the tab and
  confirm it still has rows and the same price. A cheap rare found two hours ago is usually
  gone — re-derive the candidate from live results instead of pinning to it.
- **Persist the pool to disk as you go**: `~/pob/pool/<League>/<slot>.json` with
  `{fetchedAt, query, rows}`, TTL 15 minutes. Agent context is not storage — tab ids and
  in-page state (`window.__p`) die with the tab, and a closed tab must not cost a search.
- **One `execute` block per phase for the PoB side** (all simulations together, one
  reload per set). PoB import is ~7 s, re-`add_item` ~1 s; cache the XML, don't re-import.


## Report

`node scripts/table.mjs --pick <set> --file <sim output>` renders the gates and both
tables; the buy list comes from `pool.mjs show`. Every item handed over carries:
price · item · base · **req** · Δlife · ΔEHP · Δarmour · overcap F/C/L · Δchaos · ΔDPS.
Then the pick, the total spend vs budget, and what is left to upgrade.

### Buy order = scarcity order, not value order

Present **the hardest-to-replace item first**, not the cheapest or the biggest upgrade.
A player shopping over an hour will lose the rare listing long before the common one,
so the scarce item must be bought while it exists:

- Rank by **how many comparable listings exist** — the search `total` for that slot and
  filter set is the number to quote. `total: 1` is buy-it-now or lose-it; `total: 6593`
  can wait.
- Uniques with a specific roll, and rares needing several exact mods together (life +
  cold res + chaos res on gloves), are scarce. Armour helm with life + one res is not.
- Say the count next to each item so the user can see the risk, and put a whole-budget
  warning first if the sum exceeds it.

For **every** item handed over, give the buyer an unambiguous pointer — item name and
base are not enough (rare names repeat):

- the open tab, **plus** the seller account and the price, e.g.
  `helm tab · row 2 · <account> · <price>`;
- **highlight the row in the page** rather than describing where it is: outline it, insert
  a label with name/price/seller, `scrollIntoView`, then screenshot to confirm. One glowing
  row is what answers "mở link cũng không biết mua item nào" — prose does not. The marks
  are cosmetic DOM injection and vanish on reload, so re-apply if the page refreshes;
- an exact-roll filter is **not** guaranteed unique either (life 103 + cold 36 exact still
  returned 6 rows) — combine it with the seller match to pin the row;
- and confirm the tab still has rows. "No results found" means the filter was too
  strict for that listing or it sold — rebuild the query, do not hand over an empty tab.

Never whisper or buy without explicit confirmation.

5b) ~/.config/opencode/skills/poe-gear-finder/reference/pob-sim.md

# Simulating candidates in PoB

One `execute` block. Never one tool call per candidate.

```js
const it = (name, base, mods, quality = 0) =>
  ["Rarity: RARE", name, base, "--------", "Quality: " + quality,
   "Item Level: 85", "--------", ...mods].join("\n");

const g = (t, k) => { const m = t.match(new RegExp(k + ":\\s*(-?[\\d.]+)")); return m ? +m[1] : null; };
const n = (t, k) => { const m = t.match(new RegExp('"' + k + '":\\s*(-?[\\d.]+)')); return m ? +m[1] : null; };

const snap = async () => {
  const a = String(await tools.pob.lua_get_stats({}));
  const b = String(await tools.pob.export_full_stats({ filter: "Resist" }));
  const r = (el) => ({                                  // total / cap / overcap
    t: n(b, el + "ResistTotal"),
    cap: g(a, el + "Resist"),                           // capped value from lua_get_stats
    oc: n(b, el + "ResistOverCap"),
  });
  return {
    life: g(a, "Life"), ehp: Math.round(g(a, "TotalEHP")), dps: Math.round(g(a, "CombinedDPS")),
    arm: Math.round(g(a, "Armour")), mana: g(a, "ManaUnreserved"),
    F: r("Fire"), C: r("Cold"), L: r("Lightning"), Ch: r("Chaos"),
  };
};

await tools.pob.lua_load_build({ build_name: "current.xml" });
const before = await snap();                            // equipped build, untouched
for (const [slot, text] of Object.entries(set)) {
  await tools.pob.add_item({ item_text: text, slot_name: slot });
}
const after = await snap();                             // newly equipped set
await tools.pob.lua_load_build({ build_name: "current.xml" });   // leave baseline clean
return { before, after };
```

`snap()` must be the **same function** for before and after, otherwise the two
res readings use different keys and the diff is meaningless.

`overcap` comes back `0` when the element is **at or below** its cap — chaos at
`−37` reads `cap −37 / overcap 0`. Report the total for chaos, the overcap for
elements above cap.

## Reporting res (mandatory)

Print before → after per element as `total / cap / overcap` plus the overcap
delta; see the *Res before / after* section of `SKILL.md` for the exact table and
the flags to raise (element falling below +20 overcap, element starved by the
same swap, chaos always shown).


## Rules learned the hard way

- **Unique roll ranges live in PoB's own data, not in your sample.** Grep
  `PathOfBuilding/src/Data/Uniques/<slot>.lua` before quoting a max/min roll — e.g.
  Ryslatha's Coil is `(30-40)% more Maximum Physical Attack Damage`. Inferring the range
  from the listings you happened to fetch is wrong: a small sample tops out early and
  misses the real ceiling. League-modified uniques can also roll outside PoB's data —
  say which source the number came from.
- **Measure a roll's value by holding everything else fixed.** To price a mod roll,
  simulate the same item text twice with only that number changed, so the delta is
  attributable. A whole-range delta is the useful number ("more Maximum 30→40 = +7.7%
  DPS"), not one arbitrary listing.

- **Reload before every set.** `add_item` replaces the slot but keeps everything
  else from the previous set; without a reload you diff against polluted state.
- **Slots that remove stats matter.** Replacing a belt that gave 48% fire res
  silently drops fire — the diff shows it, reasoning does not.
- **Item text format**: `Rarity / name / base / -------- / Quality: N / Item Level: N /
  -------- / mods`. Do **not** emit an `Implicits: N` header — PoB's parser
  reports it as unparseable and can mis-assign the following lines. List implicit
  mods as ordinary mod lines instead; the numeric effect is identical.
- **Quality comes from the listing, never from a guess.** Read `properties[].values` for
  `Quality`; trade omits the property entirely when an item has 0, and `parse_item` still
  reports `quality: 20`, so a text dump will happily simulate a better weapon than the one
  for sale. Pass the number you will actually buy (0 for an uncrafted drop) into `it()`.
  When the pick is within a few percent of the runner-up, simulate both at q0 before
  recommending.
- Base names must be exact (`Lacquered Helmet`, not `Lacquer Helmet`) or
  `add_item` fails with `failed to parse item`.
- `lua_get_stats` returns **capped** resistances (`FireResist` = 78 even with 200%
  over) and, worse, it is **clamped**: a build 1% short of the cap prints `76 / 76` and
  looks capped. Judge capping only from `export_full_stats({filter: "Resist"})`:
  `Missing<Element>Resist` must be `0`, and `*ResistOverCap` is the headroom (also
  clamped at 0, so pair it with `Missing`).
- `export_full_stats` with `filter: "Bleed"` gives `BleedChance`; use it instead of
  inferring from gem text (a bleed build at 100% gains nothing from more bleed chance).
- **Attribute check is mandatory.** `get_build_issues` is not enough — PoB applies
  the item's stats even when the requirement is unmet, so a healthy Life/DPS delta
  can hide an unusable item. Check the numbers directly:

  ```js
  const p = String(await tools.pob.parse_item({ text }));
  const req = JSON.parse(p.match(/\{[\s\S]*"requirements"[\s\S]*?\}(?=\s*\n\})/)[0]);
  const own = {};                                   // Str / Dex / Int of the build
  for (const k of ["Str", "Dex", "Int"]) {
    const s = String(await tools.pob.export_full_stats({ filter: k }));
    own[k] = Number(s.match(new RegExp('"' + k + '":\\s*(-?[\\d.]+)'))[1]);
  }
  const ok = req.str <= own.Str && req.dex <= own.Dex && req.int <= own.Int;
  ```

  Report the requirement next to the item (`S85 D62`) so the user can see it passes.
- Reload the original build when done, so the cached XML stays the baseline.

5c) ~/.config/opencode/skills/poe-gear-finder/reference/trade-api.md

# Trade API reference

Call it from the user's logged-in Chrome via `tools.browse.eval` — plain `fetch`
from the sandbox gets Cloudflare 403.

```js
const r = await fetch(`/api/trade/search/${league}`, {
  method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(q)
});
const { id, result, total, error } = await r.json();
const f = await fetch(`/api/trade/fetch/${result.slice(0,10).join(",")}?query=${id}`);
```

League id comes from `https://www.pathofexile.com/api/leagues` (`Covens`, `Standard`…).

## Rate limits (from response headers, do not guess)

| Endpoint | Header | Meaning |
|---|---|---|
| search | `x-rate-limit-ip: 8:10:60,15:60:120,60:300:1800` | 8 per 10s, 15 per 60s, 60 per 300s |
| search | `x-rate-limit-account: 3:5:60` | 3 per 5s per account |
| fetch | `x-rate-limit-ip: 12:4:60,16:12:60,100:300:300` | 12 per 4s |
| both | `x-rate-limit-*-state` | same shape, current usage |

The **account** rule binds first: 3 searches per 5s. A 4th search inside 5s returns
`{"code":3,"message":"Rate limit exceeded; Please wait 45/60 seconds"}` and the
account state then reads `0:5:45` — the window escalates, so a burst costs 45-60s.
Space searches ~2s apart and 4 slots never trip it.

Sleep only when a state counter reaches its limit. IP headroom is large (8/10s); do
not impose a fixed 60s pause per slot.

## Query shape

```js
{ query: {
    status: { option: "securable" },        // "securable" = instant buyout only
                                            // "online" = in person, "any" = both
    filters: {
      type_filters:  { filters: { category: { option: "armour.helmet" } } },
      armour_filters:{ filters: { ar: { min: 300 } } },   // ar / ev / es
      trade_filters: { filters: { price: { option: "chaos", max: 15 } } },
    },
    stats: [{ type: "and", filters: [
      { id: "explicit.stat_3299347043", value: { min: 100 }, disabled: false },
    ]}],
  },
  sort: { price: "asc" } }
```

## Sort options

| Sort value | Meaning |
|---|---|
| `price: "asc"` | cheapest first (default) |
| `price: "desc"` | most expensive first |
| `quality: "desc"` | highest quality first, regardless of price |

Use `quality: "desc"` when you want the best items regardless of price, then take the first few candidates.

## Getting a long candidate list

One search returns the whole id list — `sj.result` holds up to ~100 ids, there is no
"page" parameter to advance. Take as many ids as you want from it and fetch them in
chunks of 10 (10 ids per `/api/trade/fetch` call, 12 calls per 4 s):

```js
const ids = sj.result;                       // ~100 ids available
const rows = [];
for (let i = 0; i < Math.min(ids.length, 60); i += 10) {   // 40-60 candidates
  const chunk = ids.slice(i, i + 10);
  const fj = await (await fetch(`/api/trade/fetch/${chunk.join(",")}?query=${sj.id}`)).json();
  rows.push(...(fj.result || []));
}
```

60 ids = 6 fetch calls, comfortably inside the fetch budget (12 per 4 s). **Always do
this** — the 8 cheapest are not a candidate pool.

Always keep the same `queryId` (from the `/api/trade/search/<league>` response) so the
filter stays applied.

## Spacing searches

Searches are the scarce, escalating resource; fetches are cheap. Space searches ≥10 s:

```js
// in shell, between two search phases — never a burst
// sleep 12
```

Two searches back to back inside one `execute` block will trip the account rule
(`3:5` → state `0:5:45` → "wait 60 seconds"). Fetch calls in the same window are fine.

**A stored `qid` is not a cache.** Loading
`https://www.pathofexile.com/trade/search/<league>/<qid>` in a tab re-runs that search
server-side and costs one search request — same as searching again. Reading a tab that
is already open costs nothing. So: keep the tab, read the DOM, and only navigate to a
`qid` when you intend to spend a search.

Categories: `armour.helmet`, `armour.gloves`, `armour.boots`, `armour.chest`,

## Stat ids (verified against /api/trade/data/stats)

| Mod | id |
|---|---|
| `+# to maximum Life` | `explicit.stat_3299347043` |
| `+#% to Fire Resistance` | `explicit.stat_3372524247` |
| `+#% to Cold Resistance` | `explicit.stat_4220027924` |
| `+#% to Lightning Resistance` | `explicit.stat_1671376347` |
| `+#% to Chaos Resistance` | `explicit.stat_2923486259` |
| `#% increased Physical Damage` (local) | `explicit.stat_1509134228` |
| `Adds # to # Physical Damage to Attacks` | `explicit.stat_3032590688` |
| `+#% to Damage over Time Multiplier` | `explicit.stat_3988349707` |
| `#% increased Attack Speed` | `explicit.stat_681332047` |
| total elemental resistance (pseudo) | `pseudo.pseudo_total_elemental_resistance` |
| total lightning / chaos (pseudo) | `pseudo.pseudo_total_lightning_resistance`, `pseudo.pseudo_total_chaos_resistance` |

`pseudo_total_elemental_resistance` sums all elements — it hides a single-element
hole. Filter the element you actually need.

Discover an id instead of guessing:

```js
const j = await (await fetch("https://www.pathofexile.com/api/trade/data/stats")).json();
// j.result[].entries[] -> { id, text }
```

## Reading listings without another request

The rendered page already holds the results; scrape instead of re-searching:

```js
[...document.querySelectorAll(".resultset .row")].slice(0, 20).map(r => r.innerText)
```

Use `.resultset .row`, **not** `.row` — on this site version a bare `.row` matches the
Bootstrap layout rows first and returns the page header instead of listings (verified:
9 "rows" for a page showing 8 results).

Inside a row: `a[href*='/account/view-profile/']` is the seller, `button.copy` is the
whisper, and a `direct-btn` labelled "Travel to Hideout" means the listing is instant
buyout. Each row's text is `name | base | properties | mods | ~b/o N chaos | seller`.

### Marking the row you want the user to buy

The buyer's "I can't tell which one is mine" is solved by marking it, not describing it:

```js
var row = [...document.querySelectorAll(".resultset .row")].find(
  r => (r.querySelector("a[href*='/account/view-profile/']") || {}).innerText === "Seller#0000");
row.style.outline = "4px solid #ff2d55";
row.style.background = "rgba(255,45,85,0.18)";
row.scrollIntoView({ block: "center" });   // then screenshot to confirm
```

Match on the **seller** plus price: an exact-roll filter is not unique on its own (life 103
+ cold 36 exact still returned six rings). The marks are cosmetic and vanish on reload.

## Travel to Hideout (instant buyout)

Each fetched listing carries what the button needs:

| field | meaning |
|---|---|
| `listing.hideout_token` | signed JWT; the travel token. Present on every instant-buyout listing |
| `listing.fee` | **gold** the buyer pays on purchase (separate from the chaos price) |
| `listing.method` | `psapi` for instant buyout |
| `listing.indexed` | when it entered the index — old timestamp = price may be stale |

What the button needs is in the listing, but **the call itself is not reproducible from
the page** — every payload shape probed was rejected (details in `findings.md`):

| attempt | result |
|---|---|
| `POST /api/trade/whisper` body `{token}` (no extra headers) | `403` `{"code":6,"message":"Forbidden"}` |
| same + `Content-Type: application/json; charset=utf-8`, `Accept: application/json`, `X-Requested-With: XMLHttpRequest` | `400` `{"code":2,"message":"Invalid query"}` |
| bodies `{hideout_token}`, `{token, id}`, `{tokens:[…]}`, `?token=…` | all `400 Invalid query` |
| `GET /api/trade/whisper` | `403 Forbidden` (POST is the right verb) |

So the session is authenticated (the 403 → 400 change proves the cookie was accepted) but
the payload contract is not public, and it is not the naive `{token}` a forum post claims.

Rules:

- **Do not probe this endpoint further.** Guessing payloads is spray against a private
  API, and it is the ToS-grey "drive a game action" area rather than read-only trade data.
  Two attempts to confirm the shape is enough; then stop.
- To actually travel: render the search results (`trade/search/<league>/<qid>`, one search
  per qid) and **let the user press the button**. Say so plainly instead of claiming you
  can do it for them.
- **Travel is not a purchase.** The buyer still talks to the merchant NPC (Faustus) and
  pays currency + the gold `fee`. Never claim an item is bought after a travel.
- The token lives only in the page state that fetched the listing (`window.__p.rows`). A
  closed tab means re-fetching the listing (a fetch, not a search).
- Report the `fee` before any travel, so the user knows the gold they need on hand.

## Pitfalls

- `type_filters` at query level → `400 Unknown or invalid top-level filter`.
- `armour_filters.filters.armour` → `400 Invalid filter: armour`; keys are `ar`, `ev`, `es`.
- `sort` with an unknown key silently falls back; `{price:"asc"}` is correct.
- `listing.price.amount/currency` (not `price.value`) in `/api/trade/fetch` results.
- Some listings carry `item.explicitMods` as objects `{description, hash, mods}`;
  use `m.description || m`.
- Price 0 / no `listing.price` = unpriced; skip for instant buyout.
- Item mod text from the site is authoritative — copy it verbatim into PoB. Values
  are rolled min-max in `mods[].magnitudes`, the row text shows the real roll.

5d) ~/.config/opencode/skills/poe-gear-finder/scripts/README.md

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

5e) ~/.config/opencode/skills/poe-gear-finder/scripts/check.mjs

#!/usr/bin/env node
// Contract lint for the skill.
//
// The skill is a contract: SKILL.md and reference/ may only change when a rule
// changes. Run data (prices, seller handles, dates, "this session") silently rots
// those files and makes every run look like it needs another edit, so it is
// rejected here instead. Evidence belongs in findings.md.
//
//   node scripts/check.mjs          # exit 1 on any violation
//
// Wired into the repo's pre-commit hook.

import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const problems = [];
const warn = [];

const read = (rel) => readFileSync(join(root, rel), "utf8");
const list = (rel, ext) =>
  readdirSync(join(root, rel))
    .filter((f) => f.endsWith(ext))
    .sort()
    .map((f) => `${rel}/${f}`);

// findings.md is the notebook: numbers, dates and sellers are its whole point.
// This file is the checker; it necessarily names the patterns it rejects.
const contract = [
  "SKILL.md",
  ...list("reference", ".md"),
  ...list("scripts", ".mjs").filter((f) => !f.endsWith("/check.mjs")),
];

const rules = [
  {
    re: /\b\d+\s?(?:c|chaos|divine)\b/g,
    why: "price — findings.md records prices, the contract states the filter",
  },
  {
    re: /#\d{4}\b/g,
    why: "account handle — findings.md",
    allow: ["#0000"],
  },
  {
    re: /\b\d{4}-\d{2}-\d{2}\b|\b\d{1,2}\/\d{1,2}\/\d{2,4}\b/g,
    why: "date — findings.md",
  },
  {
    re: /\bthis session\b/gi,
    why: '"this session" — a rule has to stand without the session',
  },
];

for (const rel of contract) {
  const text = read(rel);
  const lines = text.split("\n");
  for (const { re, why, allow = [] } of rules) {
    re.lastIndex = 0;
    for (const m of text.matchAll(re)) {
      if (allow.some((a) => m[0].includes(a))) continue;
      const line = text.slice(0, m.index).split("\n").length;
      problems.push(`${rel}:${line}  "${m[0].trim()}"  — ${why}`);
    }
  }
  if (!lines.length) problems.push(`${rel}: empty`);
}

// A spec pins a filter set. min === max is one listing's rolls, not a filter set:
// it is a run artifact and must not accumulate in the repo.
for (const rel of list("specs", ".json")) {
  let spec;
  try {
    spec = JSON.parse(read(rel));
  } catch (e) {
    problems.push(`${rel}: invalid JSON (${e.message})`);
    continue;
  }
  for (const group of spec.stats || []) {
    for (const s of group.filters || []) {
      const v = s.value || {};
      if (v.min !== undefined && v.min === v.max) {
        problems.push(
          `${rel}: pins ${s.id} to exactly ${v.min} — one listing, not a filter set; ` +
            `keep it in /tmp/opencode`
        );
      }
    }
  }
}

// Soft signal: a spec nobody documents is probably a leftover run artifact.
const readme = read("scripts/README.md");
for (const rel of list("specs", ".json")) {
  const name = rel.slice("specs/".length);
  if (!readme.includes(name)) warn.push(`${rel}: not listed in scripts/README.md`);
}

if (problems.length) {
  console.error("skill contract check FAILED\n");
  for (const p of problems) console.error("  " + p);
  console.error(
    "\nRules belong in SKILL.md/reference; evidence belongs in findings.md."
  );
  process.exit(1);
}

for (const w of warn) console.error("warn: " + w);
console.log(`skill contract clean (${contract.length} files)`);

5f) ~/.config/opencode/skills/poe-gear-finder/scripts/pool.mjs

#!/usr/bin/env node
// Persist and read the candidate pool. Agent context is not storage: a closed tab
// or a compacted context must never cost a new search.
//
//   node scripts/pool.mjs save --league Covens --slot ring --file /tmp/opencode/ring-rows.json
//   node scripts/pool.mjs show --league Covens --slot ring [--max-age 15] [--sort life]
//   node scripts/pool.mjs list --league Covens
//
// `save` also accepts the raw output of the printed eval expression, including the
// double-encoded string form, so the file can be the tool result verbatim.
import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const argv = process.argv.slice(2);
const cmd = argv[0];
const args = {};
for (let i = 1; i < argv.length; i++) {
  const a = argv[i];
  if (a.startsWith("--")) {
    const k = a.slice(2).replace(/-/g, "_");
    args[k] = argv[i + 1] && !argv[i + 1].startsWith("--") ? argv[++i] : true;
  }
}
const league = args.league;
if (!league || !cmd) {
  console.error("usage: pool.mjs <save|show|list> --league <L> [--slot <s>] [--file f] [--max-age min] [--sort life]");
  process.exit(2);
}
const dir = join(homedir(), "pob", "pool", league);
mkdirSync(dir, { recursive: true });

/** Unwrap however many layers of JSON-string encoding the tool result picked up. */
function unwrap(raw) {
  let v = raw;
  for (let i = 0; i < 4 && typeof v === "string"; i++) {
    try { v = JSON.parse(v); } catch { break; }
  }
  return v;
}

const num = (s) => {
  const m = /([+-]?\d+(?:\.\d+)?)/.exec(String(s));
  return m ? Number(m[1]) : 0;
};

/** Sum every "+N% to X Resistance" style mod, honouring multi-element mods. */
function resist(mods, elements) {
  let total = 0;
  for (const raw of mods) {
    const m = /^\+(\d+)% to (.*Resistance[s]?)$/.exec(raw.trim());
    if (!m) continue;
    const value = Number(m[1]);
    const words = m[2];
    if (/all Elemental/.test(words)) { total += value; continue; }
    if (elements.some((e) => words.startsWith(e))) total += value;
  }
  return total;
}

function derive(row) {
  // Two shapes reach here: full API rows (from search.mjs in earlier form) and the
  // compact digest that search.mjs now returns. The digest already carries the derived
  // numbers, so only normalise the keys.
  if (row.n !== undefined || row.mods === undefined) {
    return {
      name: row.n ?? row.name,
      base: row.b ?? row.base,
      priceAmount: row.p ?? row.priceAmount,
      price: row.price ?? (row.p !== undefined ? `${row.p} chaos` : null),
      seller: row.seller,
      armour: row.ar ?? row.armour ?? 0,
      evasion: row.ev ?? row.evasion ?? 0,
      es: row.es ?? 0,
      pdps: row.pdps ?? 0,
      edps: row.edps ?? 0,
      aps: row.aps ?? 0,
      crit: row.crit ?? 0,
      pdmg: row.pdmg ?? null,
      edmg: row.edmg ?? null,
      quality: row.q ?? row.quality ?? null,
      ilvl: row.ilvl ?? null,
      sockets: row.soc ?? null,
      stack: row.st ?? null,
      corrupted: row.cor ?? 0,
      extra: row.x ?? null,
      life: row.life ?? 0,
      fire: row.fire ?? 0,
      cold: row.cold ?? 0,
      lightning: row.lightning ?? 0,
      chaos: row.chaos ?? 0,
      phys: row.phys ?? "",
      mods: row.mods ?? null,
    };
  }
  const mods = row.mods || [];
  const life = num((mods.find((m) => /maximum Life$/.test(m)) || "").replace(/^\+/, ""));
  const join = mods.join(" | ");
  return {
    ...row,
    life,
    fire: resist(mods, ["Fire"]),
    cold: resist(mods, ["Cold"]),
    lightning: resist(mods, ["Lightning"]),
    chaos: num((mods.find((m) => /to Chaos Resistance/.test(m)) || "").replace(/^\+/, "")),
    dotMulti: num((join.match(/\+(\d+)% to Damage over Time Multiplier/) || [0, 0])[1]),
    physAdd: (join.match(/Adds (\d+) to (\d+) Physical Damage/) || [0, 0, 0]).slice(1, 3).map(Number),
  };
}

if (cmd === "save") {
  if (!args.slot || !args.file) { console.error("save needs --slot and --file"); process.exit(2); }
  const payload = unwrap(readFileSync(args.file, "utf8"));
  const rows = Array.isArray(payload) ? payload : payload.rows;
  if (!Array.isArray(rows)) { console.error("no rows array in the input file"); process.exit(2); }
  const out = {
    fetchedAt: new Date().toISOString(),
    slot: args.slot,
    qid: payload && payload.qid,
    total: payload && payload.total,
    idsAvailable: payload && payload.idsAvailable,
    rows: rows.map(derive),
  };
  const file = join(dir, `${args.slot}.json`);
  writeFileSync(file, JSON.stringify(out, null, 1));
  console.log(`saved ${out.rows.length} rows (total ${out.total}) -> ${file}`);
  process.exit(0);
}

if (cmd === "list") {
  const files = readdirSync(dir).filter((f) => f.endsWith(".json"));
  for (const f of files) {
    const j = JSON.parse(readFileSync(join(dir, f), "utf8"));
    const age = ((Date.now() - statSync(join(dir, f)).mtimeMs) / 60000).toFixed(1);
    console.log(`${f.padEnd(18)} ${String(j.rows.length).padStart(3)} rows  total ${j.total}  age ${age}min`);
  }
  process.exit(0);
}

if (cmd === "show") {
  const file = join(dir, `${args.slot}.json`);
  if (!existsSync(file)) { console.error(`no pool for ${args.slot}; search first`); process.exit(4); }
  const maxAge = Number(args.max_age || 15);
  const ageMin = (Date.now() - statSync(file).mtimeMs) / 60000;
  if (ageMin > maxAge) {
    console.error(`STALE: ${args.slot} pool is ${ageMin.toFixed(1)}min old (max ${maxAge}). Listing prices move; re-search or accept the risk explicitly.`);
    process.exit(4);
  }
  const pool = JSON.parse(readFileSync(file, "utf8"));
  const isWeapon = pool.rows.some((r) => (r.pdps || 0) > 0 || (r.edps || 0) > 0);
  const key = args.sort || (isWeapon ? "pdps" : "life");
  const rows = [...pool.rows].sort((a, b) => Number(b[key] || 0) - Number(a[key] || 0)).slice(0, Number(args.limit || 15));
  console.log(`# ${args.slot} · total ${pool.total} · fetched ${pool.rows.length} · ${ageMin.toFixed(1)}min old · sorted by ${key}\n`);
  if (isWeapon) {
    console.log("price | item | base | pDPS | eDPS | phys range | aps | crit | q | ilvl | seller");
    for (const r of rows) {
      console.log(`${r.priceAmount}c | ${r.name} | ${r.base} | ${r.pdps || 0} | ${r.edps || 0} | ${r.pdmg || "–"} | ${r.aps || 0} | ${r.crit || 0} | ${r.quality ?? 0} | ${r.ilvl ?? "–"} | ${r.seller}`);
    }
  } else {
    console.log("price | item | base | armour | ev | es | life | res F/C/L | chaos | ilvl | seller");
    for (const r of rows) {
      console.log(`${r.priceAmount}c | ${r.name} | ${r.base} | ${r.armour} | ${r.evasion} | ${r.es || 0} | ${r.life} | ${r.fire}/${r.cold}/${r.lightning} | ${r.chaos} | ${r.ilvl ?? "–"} | ${r.seller}`);
    }
  }
  process.exit(0);
}

console.error(`unknown command: ${cmd}`);
process.exit(2);

5g) ~/.config/opencode/skills/poe-gear-finder/scripts/search.mjs

#!/usr/bin/env node
// Build the browser-side expression for a trade search, and enforce the search
// spacing rule mechanically (mtime lock) so it cannot be violated by accident.
//
//   node scripts/search.mjs --league Covens --slot ring --spec specs/ring.json
//
// Prints a ready-to-paste `expression` argument for tools.browse.eval, plus the
// shell command that saves the result into the pool. Nothing here performs a
// request; only the browser does, from the user's logged-in session.
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const MIN_GAP_MS = 10_000;      // searches must be >= 10s apart
const BURST_WINDOW_MS = 30 * 60_000;
const BURST_MAX = 4;            // more than this in 30min needs --force

const args = {};
for (let i = 2; i < process.argv.length; i++) {
  const a = process.argv[i];
  if (a.startsWith("--")) {
    const k = a.slice(2).replace(/-/g, "_");
    const v = process.argv[i + 1] && !process.argv[i + 1].startsWith("--") ? process.argv[++i] : true;
    args[k] = v;
  }
}
const league = args.league;
const slot = args.slot;
const specPath = args.spec;
const maxIds = Number(args.max || 60);
if (!league || !slot || !specPath) {
  console.error("usage: search.mjs --league <L> --slot <slot> --spec <spec.json> [--max 60] [--force]");
  process.exit(2);
}

const dir = join(homedir(), "pob", "pool", league);
mkdirSync(dir, { recursive: true });
const gapFile = join(dir, ".lastsearch");
const logFile = join(dir, ".searchlog");
const readIf = (p) => (existsSync(p) ? readFileSync(p, "utf8") : "");

const now = Date.now();
if (!args.reuse && !args.force && existsSync(gapFile)) {
  const last = Number(readFileSync(gapFile, "utf8").trim()) || 0;
  const wait = MIN_GAP_MS - (now - last);
  if (wait > 0) {
    console.error(`BLOCKED: last search was ${((now - last) / 1000).toFixed(1)}s ago. Wait ${Math.ceil(wait / 1000)}s, then rerun.`);
    process.exit(3);
  }
}
if (!args.reuse && !args.force && existsSync(logFile)) {
  const stamps = readFileSync(logFile, "utf8").split("\n").filter(Boolean).map(Number);
  const recent = stamps.filter((t) => now - t < BURST_WINDOW_MS);
  if (recent.length >= BURST_MAX) {
    console.error(`BLOCKED: ${recent.length} searches in the last 30min (cap ${BURST_MAX}). Spend a fetch or read a cached pool instead; --force to override.`);
    process.exit(3);
  }
}

const spec = JSON.parse(readFileSync(specPath, "utf8"));
const query = {
  query: {
    status: { option: spec.status || "securable" },   // instant buyout only
    ...(spec.term ? { term: spec.term } : {}),
    filters: spec.filters || {},
    ...(spec.stats ? { stats: spec.stats } : {}),
  },
  sort: spec.sort || { price: "asc" },
};

// Reserve the slot before emitting, so a failed run still counts. --reuse only re-reads the
// ids already stored in the tab (a fetch), so it spends no search and skips the gates —
// that is the retry path after a mapping bug or a closed tab.
if (!args.reuse) {
  writeFileSync(gapFile, String(now));
  writeFileSync(logFile, [...readIf(logFile).split("\n").filter(Boolean), String(now)].join("\n") + "\n");
}

const head = args.reuse
  ? `window.__p = window.__p || { rows: [] };
  var sj = { id: window.__p.qid, total: window.__p.total, result: window.__p.ids || [] };
  if (!sj.id) return JSON.stringify({ err: "no stored query in this tab — run a search first" });
  window.__p.rows = [];`
  : `window.__p = { qid: null, ids: [], rows: [], total: null };
  var r = await fetch("/api/trade/search/${league}", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(${JSON.stringify(query)})
  });
  var sj = await r.json();
  if (sj.error) return JSON.stringify({ err: sj.error });
  window.__p.qid = sj.id;
  window.__p.total = sj.total;
  window.__p.ids = sj.result || [];`;

const page = `(async function () {
  ${head}
  var take = Math.min(window.__p.ids.length, ${maxIds});
  for (var i = 0; i < take; i += 10) {
    var chunk = window.__p.ids.slice(i, i + 10);
    var fj = await (await fetch("/api/trade/fetch/" + chunk.join(",") + "?query=" + encodeURIComponent(sj.id))).json();
    window.__p.rows = window.__p.rows.concat(fj.result || []);
  }
  var clean = function (s) { return String(s && s.description !== undefined ? s.description : s).replace(/\\[([^\\]|]*)\\|([^\\]]*)\\]/g, "$2"); };
  var n0 = function (v) { var m = /(\\d+(?:\\.\\d+)?)/.exec(String(v === null || v === undefined ? "" : v)); return m ? Number(m[1]) : 0; };
  var KNOWN = ["Armour", "Evasion Rating", "Energy Shield", "Quality", "Physical Damage",
    "Attacks per Second", "Elemental Damage", "Critical Strike Chance", "Item Level", "Stack Size", "Sockets"];
  var rows = window.__p.rows.map(function (i) {
    var mods = [].concat(i.item.implicitMods || [], i.item.explicitMods || []).map(clean);
    var props = {};
    (i.item.properties || []).forEach(function (p) { if (p.values && p.values[0]) props[p.name] = p.values[0][0]; });
    var extra = {};
    Object.keys(props).forEach(function (k) { if (KNOWN.indexOf(k) < 0) extra[k] = props[k]; });
    return {
      name: i.item.name,
      base: i.item.baseType,
      price: i.listing && i.listing.price ? i.listing.price.amount + " " + i.listing.price.currency : null,
      priceAmount: i.listing && i.listing.price ? i.listing.price.amount : null,
      seller: i.listing && i.listing.account ? i.listing.account.name : null,
      armour: n0(props["Armour"]), evasion: n0(props["Evasion Rating"]), es: n0(props["Energy Shield"]),
      pdmg: props["Physical Damage"] || null,
      aps: props["Attacks per Second"] || null,
      edmg: props["Elemental Damage"] || null,
      crit: props["Critical Strike Chance"] || null,
      quality: props["Quality"] || null,
      ilvl: n0(props["Item Level"]),
      stack: n0(props["Stack Size"]),
      sockets: props["Sockets"] || null,
      corrupted: i.item.corrupted ? 1 : 0,
      extra: Object.keys(extra).length ? extra : null,
      requirements: (i.item.requirements || []).map(function (r) { return r.name + " " + r.values[0][0]; }),
      mods: mods
    };
  });
  window.__p.full = function (indexes) {
    return JSON.stringify(indexes.map(function (n) { return rows[n]; }));
  };
  // One digest shape for every item class: generic defensives, weapon numbers when the
  // item has them, and an "x" map for any property not named above (flask charges, gem
  // lines, stack sizes...). 60 full rows with mod text is ~30KB and would not survive the
  // trip back through the model; full text stays in the page for window.__p.full([...]).
  var sum = function (text, re) { var s = 0, x, rr = new RegExp(re, "g"); while ((x = rr.exec(text)) !== null) { s += Number(x[1]); } return s; };
  var range = function (v) { var m = /(\\d+(?:\\.\\d+)?)-(\\d+(?:\\.\\d+)?)/.exec(String(v || "")); return m ? (Number(m[1]) + Number(m[2])) / 2 : 0; };
  var digest = rows.map(function (r) {
    var t = (r.mods || []).join(" | ");
    var one = function (re) { var m = new RegExp(re).exec(t); return m ? Number(m[1]) : 0; };
    var elemAll = sum(t, "[+](\\\\d+)% to all Elemental Resistances");
    var apsN = parseFloat(r.aps || "") || 0;
    return {
      n: r.name, b: r.base, p: r.priceAmount, seller: r.seller,
      ar: r.armour, ev: r.evasion, es: r.es,
      pdps: Math.round(range(r.pdmg) * apsN), edps: Math.round(range(r.edmg) * apsN),
      aps: apsN, crit: n0(r.crit), pdmg: r.pdmg, edmg: r.edmg,
      q: n0(r.quality), ilvl: r.ilvl, soc: r.sockets, st: r.stack, cor: r.corrupted, x: r.extra,
      life: one("[+](\\\\d+) to maximum Life"),
      fire: one("[+](\\\\d+)% to Fire Resistance") + elemAll + sum(t, "[+](\\\\d+)% to Fire and (?:Cold|Lightning)"),
      cold: one("[+](\\\\d+)% to Cold Resistance") + elemAll + sum(t, "[+](\\\\d+)% to Cold and (?:Fire|Lightning)") + sum(t, "[+](\\\\d+)% to Fire and Cold"),
      lightning: one("[+](\\\\d+)% to Lightning Resistance") + elemAll + sum(t, "[+](\\\\d+)% to (?:Fire|Cold) and Lightning"),
      chaos: one("[+](\\\\d+)% to Chaos Resistance"),
      phys: (t.match(/Adds (\\d+) to (\\d+) Physical Damage/) || [0, 0, 0]).slice(1, 3).join("-")
    };
  });
  return JSON.stringify({ qid: window.__p.qid, total: window.__p.total, idsAvailable: window.__p.ids.length, fetched: rows.length, digest: digest });
})()`;

// Self-check before printing: escaping bugs in the emitted page code (a stray backtick,
// a bad regex escape) would only surface in the browser, as a silent wrong result.
{
  const { execFileSync } = await import("node:child_process");
  const { mkdtempSync, writeFileSync } = await import("node:fs");
  const { tmpdir } = await import("node:os");
  const { join } = await import("node:path");
  const check = join(mkdtempSync(join(tmpdir(), "pobsearch-")), "check.mjs");
  writeFileSync(check, "async function __r() {\nconst x = " + JSON.stringify(page) + ";\nreturn x;\n}\n");
  try {
    execFileSync("node", ["--check", check], { stdio: "pipe" });
    console.error("expression syntax check: ok");
  } catch (e) {
    console.error("SYNTAX CHECK FAILED — do not paste this expression:");
    console.error(String(e.stderr || e.message).slice(0, 400));
    process.exit(1);
  }
}

console.log("=== expression (paste verbatim as the browse.eval `expression` argument)");
// Emit the literal in chunks joined with `+` so no line exceeds a reader's per-line
// limit: string literals concatenate, so the pasted value is byte-identical.
{
  const pieces = [];
  for (let i = 0; i < page.length; i += 1400) pieces.push(JSON.stringify(page.slice(i, i + 1400)));
  console.log(pieces.join(" +\n"));
}
console.log("");
console.log("=== full mod text for chosen rows lives in the page: paste this as a second browse.eval expression");
console.log('window.__p.full([0,1,2])');
console.log("");
console.log("=== then save the returned rows to the pool");
console.log(`node scripts/pool.mjs save --league ${league} --slot ${slot} --file /tmp/opencode/${slot}-rows.json`);

5h) ~/.config/opencode/skills/poe-gear-finder/scripts/sim.mjs

#!/usr/bin/env node
// Emit a complete, ready-to-paste code-mode program that simulates every gear set
// in PoB, snapshots the stats and resistances, and checks attribute requirements.
// The model never hand-writes the sim code, so escaping cannot bite.
//
//   node scripts/sim.mjs --build current.xml --items items.json --sets sets.json > /tmp/opencode/sim.js
//
// items.json: { "<key>": { "name": "...", "base": "...", "mods": ["..."], "rarity": "RARE" } }
// sets.json:  { "<label>": { "cost": 67, "Helmet": "<key>", "Belt": "<key>", ... } }
//             slot names are PoB's: Helmet Gloves Belt "Ring 1" "Ring 2" Boots Body Armour
import { readFileSync } from "node:fs";

const argv = process.argv.slice(2);
const args = {};
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a.startsWith("--")) {
    const k = a.slice(2).replace(/-/g, "_");
    args[k] = argv[i + 1] && !argv[i + 1].startsWith("--") ? argv[++i] : true;
  }
}
if (!args.items || !args.sets) {
  console.error("usage: sim.mjs --build <build.xml> --items items.json --sets sets.json");
  process.exit(2);
}
const build = args.build || "current.xml";
const items = JSON.parse(readFileSync(args.items, "utf8"));
const sets = JSON.parse(readFileSync(args.sets, "utf8"));

// Build each item's PoB text here; no Implicits header, implicits are ordinary mods.
const texts = {};
for (const [key, it] of Object.entries(items)) {
  const head = [`Rarity: ${it.rarity || "RARE"}`, it.name, it.base, "--------", `Item Level: ${it.ilvl || 85}`, "--------"];
  texts[key] = head.concat(it.mods).join("\n");
}

const program = `const ITEMS = ${JSON.stringify(texts, null, 2)};
const SETS = ${JSON.stringify(sets, null, 2)};
const BUILD = ${JSON.stringify(build)};

const g = (t, k) => { const m = t.match(new RegExp(k + ":\\\\s*(-?[\\\\d.]+)")); return m ? +m[1] : null; };
const n = (t, k) => { const m = t.match(new RegExp('"' + k + '":\\\\s*(-?[\\\\d.]+)')); return m ? +m[1] : null; };

const snap = async () => {
  const a = String(await tools.pob.lua_get_stats({}));
  const res = String(await tools.pob.export_full_stats({ filter: "Resist" }));
  const bleed = String(await tools.pob.export_full_stats({ filter: "Bleed" }));
  // The cap must come from Missing<El>Resist, never from lua_get_stats: that value is
  // already clamped to the cap, so a build 1% short reads as "capped" there.
  const r = (el) => ({
    total: n(res, el + "ResistTotal"),
    overcap: n(res, el + "ResistOverCap"),
    missing: n(res, "Missing" + el + "Resist"),
  });
  return {
    life: g(a, "Life"),
    ehp: g(a, "TotalEHP") === null ? null : Math.round(g(a, "TotalEHP")),
    armour: g(a, "Armour") === null ? null : Math.round(g(a, "Armour")),
    dps: g(a, "CombinedDPS") === null ? null : Math.round(g(a, "CombinedDPS")),
    bleedDps: n(bleed, "BleedDPS") === null ? null : Math.round(n(bleed, "BleedDPS")),
    bleedChance: n(bleed, "BleedChance"),
    fire: r("Fire"), cold: r("Cold"), lightning: r("Lightning"), chaos: r("Chaos"),
  };
};

await tools.pob.lua_load_build({ build_name: BUILD });

// Gate: attribute requirements, checked on the build as loaded.
const own = {};
for (const k of ["Str", "Dex", "Int"]) {
  const s = String(await tools.pob.export_full_stats({ filter: k }));
  own[k] = n(s, k);
}
const reqs = {};
for (const [key, text] of Object.entries(ITEMS)) {
  try {
    const p = String(await tools.pob.parse_item({ text }));
    const m = p.match(/"requirements":\\s*\\{[^}]*\\}/);
    const req = m ? JSON.parse("{" + m[0] + "}").requirements : null;
    reqs[key] = req ? {
      str: req.str || 0, dex: req.dex || 0, int: req.int || 0, level: req.level || 0,
      ok: (req.str || 0) <= own.Str && (req.dex || 0) <= own.Dex && (req.int || 0) <= own.Int,
    } : null;
  } catch (e) {
    reqs[key] = { error: String(e).slice(0, 80) };
  }
}

const out = { build: BUILD, own, reqs, base: await snap() };
for (const [label, set] of Object.entries(SETS)) {
  await tools.pob.lua_load_build({ build_name: BUILD });   // reload: add_item keeps prior sets
  for (const [slot, key] of Object.entries(set)) {
    if (slot === "cost" || !ITEMS[key]) continue;
    await tools.pob.add_item({ item_text: ITEMS[key], slot_name: slot });
  }
  out[label] = { cost: set.cost, ...(await snap()) };
}
await tools.pob.lua_load_build({ build_name: BUILD });
return out;`;

// Self-check: the program is written for the code-mode runtime (top-level await,
// top-level return). Wrap it in a function so `node --check` can validate the syntax
// here, rather than discovering a broken program after pasting it.
try {
  const { execFileSync } = await import("node:child_process");
  const { mkdtempSync, writeFileSync } = await import("node:fs");
  const { tmpdir } = await import("node:os");
  const { join } = await import("node:path");
  const check = join(mkdtempSync(join(tmpdir(), "pobsim-")), "check.mjs");
  writeFileSync(check, "async function __run() {\n" + program + "\n}\n");
  execFileSync("node", ["--check", check], { stdio: "pipe" });
  console.error("syntax check: ok");
} catch (e) {
  console.error("SYNTAX CHECK FAILED — do not paste this program:");
  console.error(String(e.stderr || e.message).slice(0, 400));
  process.exit(1);
}

process.stdout.write(program + "\n");
console.error(`sim program ready: ${Object.keys(items).length} items, ${Object.keys(sets).length} sets, build ${build}`);
console.error(`paste it into the code-mode \`execute\` tool, then:`);
console.error(`  node scripts/table.mjs --pick <label> --file /tmp/opencode/sim-out.json`);

5i) ~/.config/opencode/skills/poe-gear-finder/scripts/table.mjs

#!/usr/bin/env node
// Render the sim output as the report tables, and run the mechanical gates:
// resistance caps, overcap >= 20, and attribute requirements. Prints markdown.
//
//   node scripts/table.mjs --pick A < /tmp/opencode/sim-out.json
//
// Input is the raw return value of the sim program, double-encoded or not.
import { readFileSync } from "node:fs";

const argv = process.argv.slice(2);
const args = {};
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a.startsWith("--")) {
    const k = a.slice(2).replace(/-/g, "_");
    args[k] = argv[i + 1] && !argv[i + 1].startsWith("--") ? argv[++i] : true;
  }
}
const raw = args.file ? readFileSync(args.file, "utf8") : readFileSync(0, "utf8");
let data = raw;
for (let i = 0; i < 4 && typeof data === "string"; i++) {
  try { data = JSON.parse(data); } catch { break; }
}
if (!data || typeof data !== "object" || !data.base) {
  console.error("could not read sim output: expected an object with a `base` key");
  process.exit(2);
}

const SET_KEYS = ["fire", "cold", "lightning", "chaos"];
const ELEM = ["fire", "cold", "lightning"];
const OVERCAP_TARGET = 20;

// Capped can only be judged from Missing<El>Resist: the baseline `FireResist` value is
// clamped to the cap, so a build 1% short of the cap reads as "capped" there.
const short = (s, e) => (s[e].missing ?? 0) > 0;
const thinOf = (s) => ELEM.filter((e) => !short(s, e) && (s[e].overcap ?? 0) < OVERCAP_TARGET);
const shortOf = (s) => ELEM.filter((e) => short(s, e));

const delta = (a, b) => (a === null || b === null ? null : b - a);
const signed = (v) => (v === null ? "–" : (v > 0 ? "+" : "") + v);
const pct = (a, b) => (a ? signed(Math.round(((b / a) - 1) * 1000) / 10) + "%" : "–");
const ocTxt = (s, e) => (short(s, e) ? `⚠short ${s[e].missing}` : signed(s[e].overcap));

const labels = Object.keys(data).filter((k) => !["build", "own", "reqs", "base"].includes(k));
const base = data.base;
const pick = args.pick && data[args.pick] ? args.pick : labels[labels.length - 1];

console.log("## Gate\n");
const badReqs = Object.entries(data.reqs || {}).filter(([, r]) => !r || r.error || !r.ok);
console.log(
  `- attributes: ${badReqs.length ? "**FAIL** " + badReqs.map(([k]) => k).join(", ") : "pass"} ` +
    `(build Str ${data.own.Str} / Dex ${data.own.Dex} / Int ${data.own.Int})`
);
if (badReqs.length) {
  for (const [k, r] of badReqs) console.log(`  - ${k}: ${r && r.error ? r.error : `needs S${r.str} D${r.dex} I${r.int}`}`);
}
const pickSet = data[pick];
const shortPick = shortOf(pickSet);
const thinPick = thinOf(pickSet);
console.log(`- res caps (${pick}): ${shortPick.length ? "**FAIL** " + shortPick.map((e) => `${e} short ${pickSet[e].missing}`).join(", ") : "all elements capped"}`);
console.log(`- overcap >= ${OVERCAP_TARGET} (${pick}): ${thinPick.length ? "**thin** " + thinPick.map((e) => `${e} +${pickSet[e].overcap}`).join(", ") : "ok"}`);
console.log(`- chaos (${pick}): total ${pickSet.chaos.total}, still short ${pickSet.chaos.missing} of the cap (informational; negative is normal)`);

console.log("\n## Sets\n");
console.log("| Set | Cost | Life | EHP | Armour | DPS | BleedDPS | Overcap F/C/L | Chaos |");
console.log("|---|---|---|---|---|---|---|---|---|");
for (const label of labels) {
  const s = data[label];
  const oc = ELEM.map((e) => ocTxt(s, e)).join(" / ");
  const bad = shortOf(s);
  const thinSet = thinOf(s);
  const flag = bad.length ? ` ⚠uncapped(${bad.map((e) => `${e} short ${s[e].missing}`).join(",")})` : thinSet.length ? ` ⚠thin(${thinSet.join(",")})` : "";
  console.log(
    `| ${label}${label === pick ? " **(pick)**" : ""}${flag} | ${s.cost ?? "–"} | ${signed(delta(base.life, s.life))} | ` +
      `${signed(delta(base.ehp, s.ehp))} (${pct(base.ehp, s.ehp)}) | ${signed(delta(base.armour, s.armour))} | ` +
      `${signed(delta(base.dps, s.dps))} (${pct(base.dps, s.dps)}) | ${signed(delta(base.bleedDps, s.bleedDps))} | ${oc} | ${s.chaos.total} |`
  );
}

console.log(`\n## Res before / after (${pick})\n`);
console.log("| Res | Trước total / overcap | Sau total / overcap | Δ |");
console.log("|---|---|---|---|");
for (const e of SET_KEYS) {
  const b = base[e], a = pickSet[e];
  const txt = (x) => `${x.total} / ${short({ [e]: x }, e) ? `short ${x.missing}` : signed(x.overcap)}`;
  const change = e === "chaos" ? (a.total ?? 0) - (b.total ?? 0) : short(pickSet, e) || short(base, e) ? (a.total ?? 0) - (b.total ?? 0) : (a.overcap ?? 0) - (b.overcap ?? 0);
  console.log(`| ${e[0].toUpperCase() + e.slice(1)} | ${txt(b)} | ${txt(a)} | ${signed(change)} |`);
}

console.log(`\n_bleed chance ${pickSet.bleedChance}% · baseline life ${base.life} · base DPS ${base.dps}_`);

5j) ~/.config/opencode/skills/poe-gear-finder/specs/axe-cheap.json

{
  "status": "securable",
  "filters": {
    "type_filters": { "filters": { "category": { "option": "weapon.twoaxe" } } },
    "trade_filters": { "filters": { "price": { "option": "chaos", "max": 10 } } }
  },
  "stats": [],
  "sort": { "pdps": "desc" }
}

5k) ~/.config/opencode/skills/poe-gear-finder/specs/belt-ryslatha.json

{
  "status": "securable",
  "term": "Ryslatha's Coil",
  "filters": {
    "trade_filters": { "filters": { "price": { "option": "chaos", "max": 60 } } }
  },
  "stats": [],
  "sort": { "price": "asc" }
}

5l) ~/.config/opencode/skills/poe-gear-finder/specs/gloves-chaos-cold.json

{
  "status": "securable",
  "filters": {
    "type_filters": { "filters": { "category": { "option": "armour.gloves" } } },
    "armour_filters": { "filters": { "ar": { "min": 100 } } },
    "trade_filters": { "filters": { "price": { "option": "chaos", "max": 20 } } }
  },
  "stats": [
    { "type": "and", "filters": [
      { "id": "explicit.stat_2923486259", "value": { "min": 20 }, "disabled": false },
      { "id": "explicit.stat_4220027924", "value": { "min": 25 }, "disabled": false },
      { "id": "explicit.stat_3299347043", "value": { "min": 80 }, "disabled": false }
    ]}
  ],
  "sort": { "price": "asc" }
}

5m) ~/.config/opencode/skills/poe-gear-finder/specs/ring-chaos.json

{
  "status": "securable",
  "filters": {
    "type_filters": { "filters": { "category": { "option": "accessory.ring" } } },
    "trade_filters": { "filters": { "price": { "option": "chaos", "max": 20 } } }
  },
  "stats": [
    { "type": "and", "filters": [
      { "id": "explicit.stat_2923486259", "value": { "min": 20 }, "disabled": false },
      { "id": "explicit.stat_3299347043", "value": { "min": 65 }, "disabled": false }
    ]}
  ],
  "sort": { "price": "asc" }
}

5n) ~/.config/opencode/skills/poe-gear-finder/specs/ring.json

{
  "status": "securable",
  "filters": {
    "type_filters": { "filters": { "category": { "option": "accessory.ring" } } },
    "trade_filters": { "filters": { "price": { "option": "chaos", "max": 10 } } }
  },
  "stats": [
    { "type": "and", "filters": [
      { "id": "explicit.stat_3299347043", "value": { "min": 90 }, "disabled": false },
      { "id": "pseudo.pseudo_total_elemental_resistance", "value": { "min": 90 }, "disabled": false }
    ]}
  ],
  "sort": { "price": "asc" }
}

5o) ~/.config/opencode/skills/poe-gear-finder/findings.md

# Findings — evidence log

**Append-only, and not instructions.** The rules live in `SKILL.md` and `reference/*`;
this file records what produced them, so a rule can be re-checked instead of re-derived.

Write one line per finding, dated, with the numbers that made it true:

```
- YYYY-MM-DD · <slot> · <measurement> → <rule it implies>
```

Copy a finding into the contract only when it changes an answer, and strip the listing
specifics on the way in (seller, price, that one item's name).

## Friction (patch queue)

One line each, added during a run, cleared when the contract is patched:

- (nothing pending)

## Log

- 2026-11-18 · res · `lua_get_stats` reports `FireResist` clamped to the cap; a build 1%
  short printed `76 / 76` and looked capped → cap checks must read
  `Missing<Element>Resist` + `*ResistOverCap` from `export_full_stats({filter:"Resist"})`.
- 2026-11-18 · travel-to-hideout · `POST /api/trade/whisper` with `{token}` → `403 code 6`;
  with XHR headers → `400 "Invalid query"`; `{hideout_token}`, `{token,id}`,
  `{tokens:[…]}`, `?token=` all `400` → the payload contract is not reachable from the
  page. Stop probing; report `fee`, keep the tab, let the user press the button.
- 2026-11-19 · axe · bleed scales with damage per hit, not pDPS: a 756-pDPS Ezomyte Axe
  (40c) hit for 193.8k and gave **−7.8%** bleed, while the equipped 686-pDPS axe hit for
  216.0k at **+0%**; a 659-pDPS Vaal Axe gave **−13.7%**. Attack speed only raises hit
  count, and bleed does not stack.
- 2026-11-19 · axe · a 3c Karui Chopper (103% inc phys, +43% DoT multi, q0) beat the
  equipped axe by **+9.7%** bleed (477.4k vs 435.4k) — cheapest listing in the run.
  Cheapest-10c rares otherwise ranged −5% to −48%.
- 2026-11-19 · axe · a league-variant unique (Foulborn Uul-Netol's Embrace, 309% inc phys
  + "Bleeding you inflict deals Damage 21% Faster") measured **+24.4% DPS / +32.2% bleed**
  at 3c, but carries `80% reduced Intelligence` (Int 105 → 21) and reduced attack speed —
  the attribute hit, not the speed, is the disqualifier.
- 2026-11-19 · axe · quality is a trap. Trade returns no `Quality` property for an item
  with 0 quality, and `parse_item` then reports `quality: 20`; feeding `Quality: 0` to
  `add_item` changed nothing in one test but `Quality: 21` did change the result in
  another. Never assume quality — read `properties[].values` for `Quality`, and when a
  candidate sits within a few percent of the pick, simulate it at the quality you will
  actually buy (q0 for an uncrafted drop).
- 2026-11-19 · rings · an exact-roll filter (`life 103`, `cold 36`) still returned 6 rows;
  rare names repeat across accounts → pin the row by seller match as well.

STEP 6 — restart opencode so the MCP registers, then prove BOTH halves:
  a) PoB: load any build with pob.lua_import_code and print Life/TotalEHP.
  b) runners: `node ~/.config/opencode/skills/poe-gear-finder/scripts/search.mjs
     --league Smoke --slot ring --spec .../specs/ring.json` must print an expression
     and exit 0; a second run within 10s must exit 3 with "BLOCKED". Then
     `rm -rf ~/pob/pool/Smoke` so the spacing lock does not leak into real runs.
  c) contract lint: `node ~/.config/opencode/skills/poe-gear-finder/scripts/check.mjs`
     must exit 0. It rejects prices, seller handles, dates and run references in
     SKILL.md/reference/scripts, and specs that pin one listing's exact rolls.
Report the paths you created, the PoB tree version loaded in the smoke test, and
anything that needed a workaround.
```
