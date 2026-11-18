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

STEP 5 — write the skill (3 files, exact content):

5a) ~/.config/opencode/skills/poe-gear-finder/SKILL.md

---
name: poe-gear-finder
description: Find and verify Path of Exile 1 gear upgrades on a budget using the real Path of Building engine. Use when the user asks to gear up a character, find an upgrade for a slot (helmet, rings, weapon, flask...), shop within a chaos/divine budget, compare trade listings by actual DPS/EHP impact, or asks "what should I buy next" for a PoE build.
---

# PoE gear finder (headless PoB + live trade)

Every candidate is **equipped in the build and recalculated by PoB** — never judged
from mod text. Whole run is ~90s; see *Speed rules* for why and how.

References: `reference/trade-api.md` (query shapes, stat ids, rate limits),
`reference/pob-sim.md` (simulation recipe).

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

1. **Load the build** — `lua_load_build({build_name})` (cache the XML under
   `~/pob/builds/`) or `lua_import_code({code})`. The load reply carries
   life/DPS/EHP/resistances. If the PoB MCP errors, **stop and fix the tool**
   (`~/pob/setup-pob.sh`, then the references) — never fall back to judging mods by eye
   or to a trade-only answer with no PoB numbers.
2. **Baseline**: one `lua_get_stats({})` for the keys you will diff, plus
   `export_full_stats({filter: "Resist"})` for `*ResistTotal` **and**
   `*ResistOverCap` of all four elements (fire/cold/lightning/chaos). The visible
   `FireResist` is **capped** — it hides overcap; overcap lives in
   `FireResistOverCap` / `ColdResistOverCap` / `LightningResistOverCap` /
   `ChaosResistOverCap`.
   Keep this baseline object and diff the final set against it — the res
   before/after table below is mandatory output, not an optional extra.
3. **Search every slot once, ≥10 s apart** (never batched in one burst) — `status: {option: "securable"}` = instant buyout. After each search, **paginate the fetch to 40+ ids** so the candidate pool is long, not just the 8 cheapest.
4. **Simulate all candidates in one `execute` block**: reload build → `add_item`
   for each slot → snapshot → diff. See `reference/pob-sim.md`.
5. **Attribute check, every candidate** — mandatory, not optional. `parse_item`
   returns `requirements {str, dex, int, level}`; compare with the build's own
   `Str`/`Dex`/`Int` (`export_full_stats({filter: "Str"})`). PoB still applies the
   stats when a requirement is unmet (it only prints a build issue), so a green
   Life/DPS delta does **not** mean the item is wearable.
6. **Report** one table (price | item | base | req | Δlife | ΔEHP | Δarmour |
   overcap F/C/L | ΔDPS), **plus the res before/after table below**, one
   recommendation, and leave the trade tabs open.

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
- Bleed: the DPS lever is **base/flat physical damage** on the weapon. Do not
  filter or reason about bleed chance if the build already shows `BleedChance: 100`
  in `export_full_stats({filter: "Bleed"})` — check the number, don't guess.

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
- **Rare item names are not unique.** Ten different rares are called `Blood Loop`.
  A name-only tab is the reason the user "can't tell which one to buy". To hand over a
  listing unambiguously: use an **exact-roll filter** (`value: {min: N, max: N}` on the
  distinctive mods) so the tab shows one row, and name the seller account next to it.
- **Listings expire mid-run.** Before telling the user to buy, re-read the tab and
  confirm it still has rows and the same price. A 1c rare found two hours ago is usually
  gone — re-derive the candidate from live results instead of pinning to it.
- **Persist the pool to disk as you go**: `~/pob/pool/<League>/<slot>.json` with
  `{fetchedAt, query, rows}`, TTL 15 minutes. Agent context is not storage — tab ids and
  in-page state (`window.__p`) die with the tab, and a closed tab must not cost a search.
- **One `execute` block per phase for the PoB side** (all simulations together, one
  reload per set). PoB import is ~7 s, re-`add_item` ~1 s; cache the XML, don't re-import.


## Report

| Price | Item | Base | Req | ΔLife | ΔEHP | ΔArmour | Overcap F/C/L | ΔChaos | ΔDPS |
|---|---|---|---|---|---|---|---|---|---|

Then: the single pick, the total spend vs budget, what is left to upgrade.

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
  `helm tab · row 2 · gujin1987#4540 · 1c`;
- and confirm the tab still has rows. "No results found" means the filter was too
  strict for that listing or it sold — rebuild the query, do not hand over an empty tab.

Never whisper or buy without explicit confirmation.

5b) ~/.config/opencode/skills/poe-gear-finder/reference/trade-api.md

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
[...document.querySelectorAll(".row")].slice(0,20).map(r => r.innerText)
```

Each row's text is `name | base | properties | mods | ~b/o N chaos | seller`.
Cheap and needs no API call — use it for follow-up questions on the same search.

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

5c) ~/.config/opencode/skills/poe-gear-finder/reference/pob-sim.md

# Simulating candidates in PoB

One `execute` block. Never one tool call per candidate.

```js
const it = (name, base, mods) =>
  ["Rarity: RARE", name, base, "--------", "Item Level: 85", "--------", ...mods].join("\n");

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
  from the listings you happened to fetch is wrong: a ≤60c sample topped out at 36% and
  missed the real 40% ceiling. League-modified uniques can also roll outside PoB's data
  (observed `54% less Minimum` against a listed `(30-40)` range) — say which source the
  number came from.
- **Measure a roll's value by holding everything else fixed.** To price a mod roll,
  simulate the same item text twice with only that number changed, so the delta is
  attributable. A whole-range delta is the useful number ("more Maximum 30→40 = +7.7%
  DPS"), not one arbitrary listing.

- **Reload before every set.** `add_item` replaces the slot but keeps everything
  else from the previous set; without a reload you diff against polluted state.
- **Slots that remove stats matter.** Replacing a belt that gave 48% fire res
  silently drops fire — the diff shows it, reasoning does not.
- **Item text format**: `Rarity / name / base / -------- / Item Level: N /
  -------- / mods`. Do **not** emit an `Implicits: N` header — PoB's parser
  reports it as unparseable and can mis-assign the following lines. List implicit
  mods as ordinary mod lines instead; the numeric effect is identical.
- Base names must be exact (`Lacquered Helmet`, not `Lacquer Helmet`) or
  `add_item` fails with `failed to parse item`.
- `lua_get_stats` returns **capped** resistances (`FireResist` = 78 even with 200%
  over). Overcap lives in `*ResistOverCap` from `export_full_stats`, which is
  truncated for an unfiltered call — always pass `filter`.
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

STEP 6 — restart opencode so the MCP registers, then prove it: load any build with
pob.lua_import_code and print Life/TotalEHP. Report the paths you created, the PoB
tree version loaded in the smoke test, and anything that needed a workaround.
```
