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

STEP 5 — write ~/.config/opencode/skills/poe-gear-finder/SKILL.md with this content:

---
name: poe-gear-finder
description: Find and verify Path of Exile 1 gear upgrades on a budget using the real Path of Building engine. Use when the user asks to gear up a character, find an upgrade for a slot (helmet, rings, weapon, flask...), shop within a chaos/divine budget, compare trade listings by actual DPS/EHP impact, or asks "what should I buy next" for a PoE build.
---

# PoE gear finder (headless PoB + live trade)

Answers "what do I buy with N chaos" with **measured** numbers, not guesses: every
candidate listing is equipped in the build and re-calculated by Path of Building.

## Prerequisites (already installed)

Everything lives under `~/pob` so the setup works on any machine with the same
home-relative layout (`$HOME` is interpolated by opencode, no absolute paths):

| Thing | Path / value |
|---|---|
| PoB source (dev branch, 3.30 tree) | `~/pob/PathOfBuilding/src` |
| PoB MCP server (MCP name `pob`) | `~/pob/pob-mcp/build/index.js` |
| Launcher used by the config | `~/pob/mcp-launch.sh` |
| Bootstrap / update (idempotent) | `~/pob/setup-pob.sh` |
| LuaJIT | `luajit` on PATH (needs `+=` support — 2026 builds do) |
| Lua modules (`xml`, `dkjson`, `socket`) | `src/lua/`, `src/dkjson.lua` |
| `lua-utf8.so` | `src/lua-utf8.so` (compiled locally) |

Fresh machine: `~/pob/setup-pob.sh` clones PoB + pob-mcp, fetches the runtime Lua
modules, compiles `lua-utf8`, builds the server and smoke-tests it. It needs git,
node ≥ 20, luajit, gcc and the LuaJIT headers; no sudo.

If any `pob` tool fails with a `Lua bridge` error, run `~/pob/setup-pob.sh` (safe to
re-run, it pulls and re-patches), then restart the MCP server. PoB's dev branch
ships files starting with `#@`, which LuaJIT rejects; the script rewrites that
header to `--@`.

## Step 1 — get the build in

Ask the user for one of:

- the PoB import code (long base64 blob), then `pob.lua_import_code({ code })`
- a saved XML, then `pob.lua_load_build({ ... })`
- `pobb.in` / `poedb` share link, then `pob.lua_import_pobb({ url })`

`lua_import_code` / `lua_load_build` return a summary (life, DPS, EHP, resists,
top issues) — read it, do **not** immediately re-call `lua_get_stats` for the same
numbers.

Confirm the league while this runs: `GET https://www.pathofexile.com/api/leagues`
returns ids (`Covens`, `Standard`, ...) — that id, lowercase-sensitive, is the
trade URL segment. Never guess it.

## Step 2 — baseline

Only pull the stats you will diff:

```
pob.lua_get_stats({})
```

Keys worth capturing: `Life`, `TotalEHP`, `Armour`, `FireResist`, `ColdResist`,
`LightningResist`, `ChaosResist`, `ManaUnreserved`, `TotalDPS`, `BleedDPS`,
`CombinedDPS`.

For defence purchases prefer `pob.analyze_defenses({ build_name, sweep_resistances: true })`
— it reports the **binding** max hit per damage type, not the EHP average, and can
drive a resistance sweep on the real engine. `TotalEHP` alone will happily recommend
patching the damage type that is already strongest.

## Step 3 — ask the budget

Always ask before searching: amount + currency (chaos / divine) and which slot(s).
Never assume "budget" means cheap. Convert: 1 divine ≈ use `pob.get_currency_rates`
or ask, not a hardcoded number.

## Step 4 — derive the filters from the build's gaps

Rules of thumb for a life/armour melee build (adjust to the actual numbers):

- `Life` under ~100 life per level → `+# to maximum Life` min 90-100 on the purchase
- any resistance overcap < 20 → take 40%+ of that resistance
- `ChaosResist` below 0 → 20-30% chaos res is worth more than 10% DPS here
- `ManaUnreserved` negative → do not buy mana-cost gear; fix reservation first
- weapons/bleed: the lever is **base physical damage** and added flat phys, not
  support-gem swaps; verify with the engine, never by reasoning about gem text

`pob.find_item_upgrades({ slot, priority })` produces a shopping spec from the
loaded build if you want PoB's own read before writing filters.

## Step 5 — search the trade site

The trade API rejects plain `fetch` (Cloudflare 403) and the search UI needs a
session, so **drive it through the user's logged-in Chrome** via the `browse`
tools (`tools.browse.navigate` + `tools.browse.eval` + `tools.browse.screenshot`).

Verified stat IDs (from `/api/trade/data/stats`; the `explicit.` prefix works, the
`pseudo.total_*` variants are equivalent for resistances):

| Mod | id |
|---|---|
| `+# to maximum Life` | `explicit.stat_3299347043` |
| `+#% to Lightning Resistance` | `explicit.stat_1671376347` |
| `+#% to Chaos Resistance` | `explicit.stat_2923486259` |
| `+#% total to Lightning Resistance` (pseudo) | `pseudo.pseudo_total_lightning_resistance` |
| `+#% total to Chaos Resistance` (pseudo) | `pseudo.pseudo_total_chaos_resistance` |
| `+#% to Fire Resistance` | `explicit.stat_3372524247` |
| `+#% to Cold Resistance` | `explicit.stat_4220027924` |
| `#% increased Physical Damage` (local weapon) | `explicit.stat_1509134228` |
| `Adds # to # Physical Damage` | `explicit.stat_3032590688` |
| `+#% to Damage over Time Multiplier` | `explicit.stat_3988349707` |

Build the query — **`type_filters` goes inside `filters`, never at query level**:

```js
const q = {
  query: {
    status: { option: "online" },
    filters: {
      type_filters: { filters: { category: { option: "armour.helmet" } } },
      // local defence value uses the short key: ar / ev / es  (NOT "armour")
      armour_filters: { filters: { ar: { min: 300 } } },
      // price cap
      // trade_filters: { filters: { price: { min: null, max: 10, option: "chaos" } } },
    },
    stats: [{ type: "and", filters: [
      { id: "explicit.stat_3299347043", value: { min: 90 }, disabled: false },
      { id: "explicit.stat_1671376347", value: { min: 40 }, disabled: false },
      { id: "explicit.stat_2923486259", value: { min: 20 }, disabled: false },
    ]}],
  },
  sort: { price: "asc" },
};
```

Then, inside the page:

```js
fetch("/api/trade/search/<LeagueId>", { method: "POST",
  headers: { "Content-Type": "application/json" }, body: JSON.stringify(q) })
  .then(r => r.json())          // -> { id, result: [...hashes], total }
fetch(`/api/trade/fetch/${ids.join(",")}?query=${id}`)
```

Load the finished URL in the tab so the user can click through:
`https://www.pathofexile.com/trade/search/<LeagueId>?q=<encodeURIComponent(JSON.stringify(q))>`.

Rate limit: ~1 search per 60s per session (`{"code":3,"message":"Rate limit
exceeded"}`). Batch — one search + one fetch per slot, then stop.

If `POE_TRADE_ENABLED=true` and `POE_SESSION_ID` are configured, `pob.search_trade_items`
and `pob.find_weighted_trade_items` can do the same in-server; the browser path
needs no session plumbing and always matches what the user sees.

## Step 6 — simulate every candidate (this is the point)

For each listing, convert it to PoE item text and equip it:

```
pob.add_item({ item_text, slot_name: "Helmet" })
pob.lua_get_stats({})
```

Diff against baseline. Item text template:

```
Rarity: RARE
<name>
<base type>
--------
Quality: +20% (augmented)
Armour: 413 (augmented)
--------
Requirements:
Level: 69
Str: 138
--------
Sockets: R-R-R-R
--------
Item Level: 85
--------
<mod lines exactly as listed>
```

Notes:

- `add_item` replaces whatever is in that slot, so candidates can be simulated
  back to back — but keep the baseline numbers from before the first swap.
- Levels/attributes can invalidate an item (e.g. `Str: 138` unmet) — PoB will show
  the requirement error; check `Life`/DPS actually moved before trusting a row.
- Re-import the original code if a run gets polluted; imports take ~7s.
- Percentage-based "increased damage" mods on a weapon are **local**; copy the
  listing's mod text verbatim instead of re-typing values.

## Step 7 — report

Rank by what the user asked to optimise, one row per listing:

| Price | Item | Base | ΔDPS | ΔLife | ΔEHP | ΔRes |
|---|---|---|---|---|---|---|

Then: the single pick, why, and the search URL sorted by price. Offer to whisper
the seller — do not whisper or buy without explicit confirmation.

## Pitfalls that already cost time here

- `type_filters` at query level → `400 Unknown or invalid top-level filter`.
- `armour_filters.filters.armour` → `400 Invalid filter: armour`; the key is `ar`
  (`ev`, `es` likewise).
- A stale trade tab shows previously unknown stats as "unavailable stat"; hard
  reload before concluding an id is wrong. Validate ids against
  `/api/trade/data/stats` instead of guessing.
- Bleed/hit claims must come from the engine. Gem-text reasoning has produced
  wrong advice before (Fortify Support and Fist of War both scale ailments; Alira
  is +15% all elemental res only since 3.25).
- The user's PoB XML may carry an older `treeVersion` than the local PoB tree;
  imports still work but say so when numbers look off.

STEP 6 — restart opencode so the MCP registers, then prove it: load any build with
pob.lua_import_code and print Life/TotalEHP. Report the paths you created, the PoB
tree version loaded in the smoke test, and anything that needed a workaround.
```
