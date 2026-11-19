# Archetypes — what each build actually scales

The classifier picks one of these from PoB's own DPS components, then applies its
metric. Never re-label a build from its skill name: "Sunder" can be a hit build, a bleed
build or a stun build, and only the numbers say which.

## Metric table

| Archetype | Signal in PoB | Metric to optimise | Dead stats |
|---|---|---|---|
| **bleed** | `BleedDPS > 0`, `TotalDotDPS > 0` | `BleedDPS` + `AverageDamage` | pDPS, attack speed, crit (unless invested), elemental added damage |
| **ignite** | `IgniteDPS > 0` | `IgniteDPS` | attack speed, crit, physical damage |
| **poison** | `PoisonDPS > 0` | `PoisonDPS` (stacks scale with hit rate) | crit multi unless invested |
| **hit** | no DoT component | `CombinedDPS` with `HitChance = 100` | ailment duration/magnitude |

`CombinedDPS` is a summary, not a target: it mixes hit and DoT and hides which half moved.
Always quote the component the archetype scales, next to the hit damage.

## Bleed (physical DoT attacks)

- Bleed does **not stack**; only the largest bleed on a target deals damage. Damage is set
  by the hit that applied it — hence damage per hit, not pDPS.
- **Aggravate** is the largest untapped multiplier: a bleeding enemy that is *moving* takes
  triple bleed damage, and aggravating an existing bleed makes a stationary enemy count as
  moving. Sources: the bleed mastery "chance to Aggravate Bleeding on targets you hit with
  Exerted Attacks", Vulnerability quality, Bloodletting, and any fast extra hit
  (Static Strike, or Hydrosphere with a slam).
- Slam supports in priority order: Fist of War, Fortify, Brutality, Melee Physical Damage,
  then one of Cruelty / Damage on Full Life / Volatility. Fortify is a support *and* a
  defensive buff — price its removal as defence, not just DPS.
- **Ryslatha's Coil** raises maximum and lowers minimum hit damage. With Volatility
  Support the low rolls become visible while mapping; the pair is a bossing setup.
- Vulnerability is the curse: increased physical damage taken, plus aggravate on quality.
- Traps: sorting by pDPS; assuming a unique is worse than a rare; trusting the `Quality:`
  line in item text (read the listing's property instead).

## Ignite

- Ignite takes the **fire damage of the hit** that applied it; `IgniteDPS` is the target.
- Needs exposure and fire penetration on the hit, and ignite duration for uptime.
- Flammability + Combustion are the cheap multipliers.

## Poison

- Poison **stacks**, so hit rate multiplies with hit size; `PoisonDPS` already accounts for
  both. Wither and chaos resistance reduction are the big levers.

## Hit

- `CombinedDPS` with `HitChance` at 100. If `CritChance` is 0 (e.g. Resolute Technique),
  crit chance and multi are dead — recommend flat damage, attack speed, gem levels.
- If hit chance is below 100, accuracy is the cheapest damage in the build.

## Build defects to report before any purchase

- `ManaUnreserved < 0`: reservation exceeds the pool, so PoB's DPS includes auras that
  cannot run. Fixes: reduced reservation (Enlighten, reservation cluster, aura efficiency),
  mana cost efficiency on rings/helmet, Life/Attack masteries that pay mana costs with
  life, or dropping an aura deliberately.
- Life under ~4.5k for red maps; negative chaos resistance; elemental overcap under +20
  (curses reach −30).
- Attribute totals must clear the item you are about to buy: `Str/Dex/Int` vs
  `ReqStr/ReqDex/ReqInt`, not the base name's typical requirement.
