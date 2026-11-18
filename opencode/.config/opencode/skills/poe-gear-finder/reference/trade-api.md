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

## Sort options

| Sort value | Meaning |
|---|---|
| `price: "asc"` | cheapest first (default) |
| `price: "desc"` | most expensive first |
| `quality: "desc"` | highest quality first, regardless of price |

Use `quality: "desc"` when you want the best items regardless of price, then take the first few candidates.

## Getting a long candidate list

One search returns the whole id list — `sj.result` holds up to ~100 ids, there is no
"page" parameter to advance. Take as many ids as you want from it and fetch them in
chunks of 10 (10 ids per `/api/trade/fetch` call, 12 calls per 4 s):

```js
const ids = sj.result;                       // ~100 ids available
const rows = [];
for (let i = 0; i < Math.min(ids.length, 60); i += 10) {   // 40-60 candidates
  const chunk = ids.slice(i, i + 10);
  const fj = await (await fetch(`/api/trade/fetch/${chunk.join(",")}?query=${sj.id}`)).json();
  rows.push(...(fj.result || []));
}
```

60 ids = 6 fetch calls, comfortably inside the fetch budget (12 per 4 s). **Always do
this** — the 8 cheapest are not a candidate pool.

Always keep the same `queryId` (from the `/api/trade/search/<league>` response) so the
filter stays applied.

## Spacing searches

Searches are the scarce, escalating resource; fetches are cheap. Space searches ≥10 s:

```js
// in shell, between two search phases — never a burst
// sleep 12
```

Two searches back to back inside one `execute` block will trip the account rule
(`3:5` → state `0:5:45` → "wait 60 seconds"). Fetch calls in the same window are fine.

**A stored `qid` is not a cache.** Loading
`https://www.pathofexile.com/trade/search/<league>/<qid>` in a tab re-runs that search
server-side and costs one search request — same as searching again. Reading a tab that
is already open costs nothing. So: keep the tab, read the DOM, and only navigate to a
`qid` when you intend to spend a search.

Categories: `armour.helmet`, `armour.gloves`, `armour.boots`, `armour.chest`,

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

## Travel to Hideout (instant buyout)

Each fetched listing carries what the button needs:

| field | meaning |
|---|---|
| `listing.hideout_token` | signed JWT; the travel token. Present on every instant-buyout listing |
| `listing.fee` | **gold** the buyer pays on purchase (separate from the chaos price) |
| `listing.method` | `psapi` for instant buyout |
| `listing.indexed` | when it entered the index — old timestamp = price may be stale |

The button is a single authenticated POST from the logged-in session:

```js
// inside the page that fetched the listing, so the session cookies apply
const r = await fetch("/api/trade/whisper", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ token: listing.hideout_token }),
});
```

Rules:

- **Only works from a town or hideout.** That is why it is safe to fire on request — it
  cannot pull the character out of a map or a boss fight. If the response is an error,
  report it; do not retry blindly.
- **Travel is not a purchase.** The buyer still talks to the merchant NPC (Faustus) and
  pays currency + the gold `fee`. Never claim an item is bought after firing the token.
- **The token lives only in the page state that fetched the listing** (`window.__p.rows`).
  If that tab is gone, the token is gone — re-fetch the listing (a fetch, not a search).
- Report the `fee` before firing, so the user knows the gold they need on hand.

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
