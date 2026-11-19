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

- 2026-11-19 · rings ≤20c (life 65+ chaos 20+) · Ring 1 owns the build's fire res: every
  Ring 1 swap uncapped or thinned fire, every Ring 2 swap kept all overcaps ≥ +20 →
  ring sims must run per-slot before picking; the "safe" ring slot is a property of the
  equipped gear, not the candidate.
- 2026-11-19 · rings · +65 maximum Mana on a ring made unreserved mana WORSE
  (−778 → −802): percentage reservations reserve more flat mana on a bigger pool →
  on a % aura build, max-mana gear deepens the reservation defect instead of padding it.
- 2026-11-19 · combo gate · gloves (−45 cold) + ring-2 swap (−24 cold) stacked to
  uncapped cold (61 vs cap 77, missing 16) even though each single passed → combos
  re-check caps on every combined set; the singles-first rule caught it before handover.
- 2026-11-19 · code-mode paste · an identical sim-program paste failed once with
  "Unterminated string constant" and succeeded on a plain retry — paste-retry first,
  never rewrite the emitted program around a transport glitch.
- 2026-11-19 · emitted page · the bracket-strip regex was structurally broken from the
  first version (`([^\]|]*)` closes its class early): pipe-free brackets corrupted to
  literal `$2` and `[x|y]` roll descriptions never stripped, under-crediting the digest
  and carrying corrupted text into `full()`/parse_item → emitted regexes must be
  byte-verified against bracket-bearing canned items in the offline harness —
  `node --check` cannot see a class that closes early.
- 2026-11-19 · digest attrs · `.*Strength.*` credited `+1 to Level of all Strength Skill
  Gems` as a Str grant → grant regexes must anchor right after `to `
  (`to (all attributes|Strength.*|...)`); hybrids and `all attributes` credit every side.
- 2026-11-19 · gloves filter · chaos 20 + cold 25 + life 80 + armour 200 within 20c
  returned 0 listings → cold was the rarest requirement; relaxing to chaos + life +
  armour returned 7 (still scarce — buy-first). An emitted-but-never-pasted search burns
  a 30-min slot; `--unmark` releases it.
- 2026-11-19 · helm/gloves pool ≤20c · every helm swap LOST net life (the equipped helm
  ~+150 life beats the pool) and every helm+gloves combo broke cold caps; only the
  gloves-only swap kept all caps → the pool's 1c Sol Talons (+30 chaos, EHP +15%) is the
  single purchase, and the cold overcap cushion falls +53→+8, so the next purchase must
  answer cold exposure → sim per-slot before combining: the equipped slot's res ownership
  decides cap survival, not the candidate's own mods.
- 2026-11-19 · axe pool ≤10c · the price-asc first-100 ids carry no DoT-multi/faster
  weapons; the best per-hit candidate (83% inc phys, q20, 1c, half its mods dead under
  Brutality/RT) simmed −29.8% bleed → a cheap weapon pool routinely loses to an invested
  bleed weapon; spend the next search on rings instead of re-ranking it.
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
