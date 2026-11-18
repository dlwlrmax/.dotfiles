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

## Ask once, at the start (one message)

1. Build: import code / XML / pobb.in link.
2. Budget: amount + currency.
3. Slots: which ones (default: ask, do not assume all).
4. Base preference: **armour / evasion / ES / any** — this changes every search.
5. Priority order: life → elemental res overcap → chaos res → DPS, unless they say otherwise.

Never re-ask mid-run because a filter returned nothing — relax filters instead
(drop the rarest requirement first, tell them what you dropped).

## Flow

1. **Load** `pob.lua_load_build({build_name})` (cache the XML under `~/pob/builds/`)
   or `lua_import_code({code})`. The load reply already carries life/DPS/EHP/resists.
2. **Baseline**: one `lua_get_stats({})` for the keys you will diff, plus
   `export_full_stats({filter: "Resist"})` for `*ResistOverCap` (the visible
   `FireResist` is **capped** — it hides overcap; overcap lives in
   `FireResistOverCap` / `ColdResistOverCap` / `LightningResistOverCap`).
3. **Search every slot once** — `status: {option: "securable"}` = instant buyout.
   Batch all slots in one `execute` block; the IP budget is 8 requests / 10s.
4. **Simulate all candidates in one `execute` block**: reload build → `add_item`
   for each slot → snapshot → diff. See `reference/pob-sim.md`.
5. **Report** one table (price | item | Δlife | ΔEHP | Δarmour | overcap F/C/L | ΔDPS),
   one recommendation, and leave the trade tabs open.

## Targets to encode as filters

- Life: `+# to maximum Life` min ≈ 1.2 × level (100+ at 84).
- Elemental res: aim **overcap ≥ 20%** per element; filter the element the build is
  thinnest on, not "total resistance" (total hides a hole in one element).
- Chaos res: only if the user says it matters.
- Armour builds: `armour_filters: {filters: {ar: {min: 300}}}` for helm,
  `ar: {min: 200}` for gloves; pick armour bases (Burgonet, Gauntlets, Plate).
- Bleed: the DPS lever is **base/flat physical damage** on the weapon. Do not
  filter or reason about bleed chance if the build already shows `BleedChance: 100`
  in `export_full_stats({filter: "Bleed"})` — check the number, don't guess.

## Speed rules (the whole point)

- **No blanket sleeps.** Read `x-rate-limit-ip-state` from the search response:
  `8:10:60` means 8 requests per 10s per IP. Four slots = 4 searches + 4 fetches
  and fits in one 10s window. Only sleep when a state counter reaches its limit.
  Blanket `sleep 60` between slots wastes 4 minutes per run.
- **One search per slot, ever.** Iterating on candidates = re-`fetch` by id
  (12 per 4s), never re-search.
- **Cache listings**: write `{fetchedAt, query, rows}` to
  `~/pob/pool/<League>/<slot>.json`; reuse if younger than 15 minutes. Re-searching
  the same slot three times to "confirm" is what made early runs slow.
- **One `execute` block per phase** (all searches, or all simulations). Each extra
  round trip costs more wall clock than the PoB math does.
- PoB import is ~7s; re-`add_item` is ~1s. Cache the XML, don't re-import.

## Report

| Price | Item | Base | ΔLife | ΔEHP | ΔArmour | Overcap F/C/L | ΔDPS |
|---|---|---|---|---|---|---|---|

Then: the single pick, the total spend vs budget, what is left to upgrade.
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

Categories: `armour.helmet`, `armour.gloves`, `armour.boots`, `armour.chest`,
`armour.shield`, `accessory.ring`, `accessory.amulet`, `accessory.belt`,
`weapon.oneaxe`, `weapon.twoaxe`, `flask`.

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
  return {
    life: g(a, "Life"), ehp: Math.round(g(a, "TotalEHP")), dps: Math.round(g(a, "CombinedDPS")),
    arm: Math.round(g(a, "Armour")), mana: g(a, "ManaUnreserved"),
    F: n(b, "FireResistOverCap"), C: n(b, "ColdResistOverCap"),
    L: n(b, "LightningResistOverCap"), Ch: n(b, "ChaosResistOverCap"),
  };
};

await tools.pob.lua_load_build({ build_name: "current.xml" });
const out = { base: await snap() };
for (const [slot, text] of Object.entries(set)) {           // one set = 5 slots
  await tools.pob.lua_load_build({ build_name: "current.xml" });   // reset first
  await tools.pob.add_item({ item_text: text, slot_name: slot });
}
out.set = await snap();
```

## Rules learned the hard way

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
- Requirements are checked: an unmet Str/Dex/Int prints a build issue but still
  applies stats — read `get_build_issues` before recommending.
- Reload the original build when done, so the cached XML stays the baseline.

STEP 6 — restart opencode so the MCP registers, then prove it: load any build with
pob.lua_import_code and print Life/TotalEHP. Report the paths you created, the PoB
tree version loaded in the smoke test, and anything that needed a workaround.
```
