# Simulating candidates in PoB

One `execute` block. Never one tool call per candidate.

## Singles first

Sim each candidate item **alone** (one set per item) before combining. A combination set
that breaks a cap tells you nothing about which item did it, and a single-item sim is the
only way to learn what the equipped slot actually carries — the equipped helm can own
half the build's cold res, and only a helm-only swap reveals that. Combine only items
whose single-set sims pass the gates, and expect combinations to redistribute res:
re-check the caps on every combined set, not just the singles.

```js
const it = (name, base, mods, { quality = 0, price = null } = {}) =>
  ["Rarity: RARE", name, base, "--------", "Item Level: 85", "Quality: " + quality,
   "--------", ...mods].join("\n");

const g = (t, k) => { const m = t.match(new RegExp(k + ":\\s*(-?[\\d.]+)")); return m ? +m[1] : null; };const n = (t, k) => { const m = t.match(new RegExp('"' + k + '":\\s*(-?[\\d.]+)')); return m ? +m[1] : null; };

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

`items.json` (the file `sim.mjs` consumes) is `{ "<key>": { name, base, mods } }` plus the
optional `rarity`, `ilvl`, **`quality`** and **`price`** fields. `price` is never simulated;
it is carried through to the per-item report so the buy list and the numbers come from
one file. The helper mirrors that: `it(name, base, mods, { quality, price })`.

**Quality is parsed but NOT applied by the calc** (measured: a q20 weapon sim is
byte-identical to q0). A `Quality: N` line in the item text changes nothing. Weapon
quality in PoE is `+N% increased Physical Damage` (local) — to simulate a quality
listing, add that as an ordinary mod line; a q20 rare then sims ~1.2x its q0 bleed.
Digest/display pdps on trade INCLUDES quality, so a q0 sim of a quality listing
understates the item by that factor.


`overcap` comes back `0` when the element is **at or below** its cap — chaos at
`−37` reads `total −37 / overcap 0`, with `MissingChaosResist` carrying the gap against
the 75 cap. Report the total for chaos, the overcap for elements above cap.

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
  for sale. The `Quality:` line itself is inert in the sim (see above) — encode the
  listing's quality as a `+N% increased Physical Damage` mod line, and when the pick is
  within a few percent of the runner-up, simulate both at the same quality before
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
- **Jewel slots are named `Jewel <passive-node-id>`, not `Jewel 1`.** Read the exact slot
  name from `get_equipped_items` before calling `add_item` — a wrong slot name silently
  adds the item unequipped, so the sim reports no change and looks like the jewel does
  nothing.
- Reload the original build when done, so the cached XML stays the baseline.

## Known conservative gaps

- **The attribute gate uses the BASE build's attributes.** Each item's requirement is
  compared against `Str/Dex/Int` as the build stands before any swap, so a set whose items
  grant each other `+Str/+Dex/+Int` can false-FAIL even though the equipped set is
  wearable. Re-check such picks by hand (or simulate and read the requirement again) —
  never reject a candidate on the gate alone in that case.
- **Item level requirements are not checked by the gate.** Only `str/dex/int` are
  compared; a listing whose `ilvl` is below the item's level requirement passes silently.
  Read the level from the listing when the base is high-tier.
