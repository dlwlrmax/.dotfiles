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
