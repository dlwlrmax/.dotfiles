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
