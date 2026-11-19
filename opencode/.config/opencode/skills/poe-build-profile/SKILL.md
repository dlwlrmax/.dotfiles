---
name: poe-build-profile
description: Identify what a Path of Exile 1 build actually scales, from the real Path of Building numbers, before any gear advice. Use at the start of a gear/upgrade request, when a build import or pobb.in link is shared, when the user asks "what does this build need", or when a guide is compared against the character. Produces archetype, the correct metric, support-gem audit and a gap checklist.
---

# PoE build profile — identify before advising

Gear advice is wrong when the build is misread: ranking a bleed build by pDPS, a crit
build by average damage, or suggesting crit multi on a Resolute Technique character.
This skill reads the **loaded PoB build** and prints what it scales, which metric is
valid, and which mechanics are missing. Run it **before** `poe-gear-finder` searches,
and hand its output to that skill.

Contract rule, same as the gear skill: `SKILL.md` and `reference/*` state rules only.
Numbers from a session go to `findings.md`.

## Flow

1. **Have the build loaded.** `lua_import_pobb({url_or_id})`, `lua_import_code({code})` or
   `lua_load_build({build_name})`. Save it: `lua_save_build({build_name})` — `analyze_build`
   reads the saved file, and the profiler needs a name.
2. **Emit the profiler program**:
   `node scripts/profile.mjs --build <name.xml> > /tmp/opencode/profile.js`
   The script syntax-checks what it emits; if it prints `SYNTAX CHECK FAILED`, stop and fix
   the script instead of pasting.
3. **Paste it into the code-mode `execute` tool.** The returned string **is** the report:
   archetype, metric, support audit, defects, free levers. No intermediate file, no second
   script — the classifier is inlined into the emitted program.
4. **Hand over**: the metric decides every later comparison. A bleed build is ranked by
   `BleedDPS` and `AverageDamage`; `CombinedDPS` and pDPS are context, not targets.

## What the profile is built from

`analyze_build` is the source: it returns PoB's own numbers (`BleedDPS`, `TotalDotDPS`,
`AverageDamage`, `Speed`, `CritChance`, `HitChance`, `ManaUnreserved`, resistances,
charges) plus the skill groups (`Sunder (19/18) - ...`) and every equipped item with its
mods. Nothing is inferred from mod text, and nothing is copied from a guide.

The only value taken outside it is the DoT component pair from `export_full_stats`, because
that dump keeps `BleedDPS`/`IgniteDPS`/`PoisonDPS` raw; `analyze_build` renames nothing but
does not always carry every component. If a field is missing the report says so instead of
guessing.

## Rules it applies

- **Archetype from numbers, not from names.** Bleed/ignite/poison DoT components decide
  it; a skill name like "Sunder" does not.
- **Crit builds need `CritChance > 0`.** At 0 (Resolute Technique, or no investment) crit
  multi and crit chance are dead stats — never recommend them.
- **Attribute headroom is a gear constraint.** `Str/Dex/Int` vs `ReqStr/ReqDex/ReqInt`
  decides whether an armour base is wearable at all.
- **Unreserved mana below zero is a build defect**, not a gear preference: PoB keeps
  computing DPS for auras that cannot run in game. Report it first.
- **Support audit** compares the main link against the archetype's priority list in
  `reference/archetypes.md`, and flags combinations that fight each other (e.g.
  Ryslatha's Coil with Volatility Support, Swift Affliction's reduced bleed duration).

See `reference/archetypes.md` for the per-archetype metric table and the mechanics each
one must have (aggravate sources for bleed, exposure for elemental DoT, ...).
