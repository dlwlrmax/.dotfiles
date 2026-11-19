# Findings — evidence log

Append-only, and **not instructions**. Rules live in `SKILL.md` and `reference/*`; this
file records the sessions that produced them.

```
- YYYY-MM-DD · <build> · <measurement> → <rule it implies>
```

## Friction (patch queue)

- (nothing pending)

## Log

- 2026-11-19 · bleed slam · pDPS and attack speed moved the number the wrong way: a
  756-pDPS axe gave less bleed than a 686-pDPS one, and a faster base lost to a slower
  hard-hitting one. `AverageDamage` tracked every result correctly → the classifier ranks
  bleed by hit damage, never pDPS.
- 2026-11-19 · bleed slam · PoB ran happily with unreserved mana at −778 and still printed
  full DPS, because reservation is not validated → a negative pool must be reported as a
  defect before damage advice, not treated as a gear preference.
- 2026-11-19 · bleed slam · `analyze_build` needs a saved build name; `lua_get_stats` alone
  has too few keys to classify → the profiler reads the saved file and parses that dump.
- 2026-11-19 · any build · `export_full_stats` is **not** JSON (leading `===` header), so
  `JSON.parse` throws → read single values with a `"Key":\s*value` regex, and keep the
  classifier inlined in the emitted program so no intermediate file is needed.
- 2026-11-19 · any build · a gem below level 20 in a utility group (Frostblink 9, Molten
  Shell 10) is not a lever → report the main link's gems by name and only count the rest.
