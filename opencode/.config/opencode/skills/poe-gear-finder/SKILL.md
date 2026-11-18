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
   `export_full_stats({filter: "Resist"})` for `*ResistTotal` **and**
   `*ResistOverCap` of all four elements (fire/cold/lightning/chaos). The visible
   `FireResist` is **capped** — it hides overcap; overcap lives in
   `FireResistOverCap` / `ColdResistOverCap` / `LightningResistOverCap` /
   `ChaosResistOverCap`.
   Keep this baseline object and diff the final set against it — the res
   before/after table below is mandatory output, not an optional extra.
3. **Search every slot once** — `status: {option: "securable"}` = instant buyout.
   Batch all slots in one `execute` block; the IP budget is 8 requests / 10s.
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
