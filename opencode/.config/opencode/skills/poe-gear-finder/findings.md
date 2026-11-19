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

- `add_item` needs the jewel slot name from `get_equipped_items` (it can be
  `Jewel <passive-node-id>`, not `Jewel 1`); a wrong slot adds the item unequipped.
- trade `category: jewel` + `explicit.stat_3988349707` (DoT multi) returns 0, while the
  same stat without the category matches weapons; the jewel stat id differs — verify
  against `/api/trade/data/stats` before trusting an empty result.
- `type_filters` category `accessory.amulet` + DoT multi + life returned 0 within 60c;
  suspected category-name mismatch, not an empty market.

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
