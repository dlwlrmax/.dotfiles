#!/usr/bin/env node
// Persist and read the candidate pool. Agent context is not storage: a closed tab
// or a compacted context must never cost a new search.
//
//   node scripts/pool.mjs save --league Covens --slot ring --file /tmp/opencode/ring-rows.json
//   node scripts/pool.mjs show --league Covens --slot ring [--max-age 15] [--sort life]
//   node scripts/pool.mjs list --league Covens
//
// `save` also accepts the raw output of the printed eval expression, including the
// double-encoded string form, so the file can be the tool result verbatim.
import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const argv = process.argv.slice(2);
const cmd = argv[0];
const args = {};
for (let i = 1; i < argv.length; i++) {
  const a = argv[i];
  if (a.startsWith("--")) {
    const k = a.slice(2).replace(/-/g, "_");
    args[k] = argv[i + 1] && !argv[i + 1].startsWith("--") ? argv[++i] : true;
  }
}
const league = args.league;
if (!league || !cmd) {
  console.error("usage: pool.mjs <save|show|list> --league <L> [--slot <s>] [--file f] [--max-age min] [--sort life]");
  process.exit(2);
}
const dir = join(homedir(), "pob", "pool", league);
mkdirSync(dir, { recursive: true });

/** Unwrap however many layers of JSON-string encoding the tool result picked up. */
function unwrap(raw) {
  let v = raw;
  for (let i = 0; i < 4 && typeof v === "string"; i++) {
    try { v = JSON.parse(v); } catch { break; }
  }
  return v;
}

const num = (s) => {
  const m = /([+-]?\d+(?:\.\d+)?)/.exec(String(s));
  return m ? Number(m[1]) : 0;
};

/** Sum every "+N% to X Resistance" style mod, honouring multi-element mods. */
function resist(mods, elements) {
  let total = 0;
  for (const raw of mods) {
    const m = /^\+(\d+)% to (.*Resistance)/.exec(raw.trim());
    if (!m) continue;
    const value = Number(m[1]);
    const words = m[2];
    if (/all Elemental/.test(words)) { total += value; continue; }
    // Every element the mod names counts, not just the one it starts with: a
    // "Fire and Cold" roll must credit both sides, as the digest path does.
    if (elements.some((e) => new RegExp(`\\b${e}\\b`).test(words))) total += value;
  }
  return total;
}

function derive(row) {
  // Two shapes reach here: full API rows (from search.mjs in earlier form) and the
  // compact digest that search.mjs now returns. The digest already carries the derived
  // numbers, so only normalise the keys.
  if (row.n !== undefined || row.mods === undefined) {
    return {
      name: row.n ?? row.name,
      base: row.b ?? row.base,
      priceAmount: row.p ?? row.priceAmount,
      price: row.price ?? (row.p !== undefined ? `${row.p} chaos` : null),
      seller: row.seller,
      armour: row.ar ?? row.armour ?? 0,
      evasion: row.ev ?? row.evasion ?? 0,
      es: row.es ?? 0,
      pdps: row.pdps ?? 0,
      edps: row.edps ?? 0,
      aps: row.aps ?? 0,
      crit: row.crit ?? 0,
      pdmg: row.pdmg ?? null,
      edmg: row.edmg ?? null,
      quality: row.q ?? row.quality ?? null,
      ilvl: row.ilvl ?? null,
      sockets: row.soc ?? null,
      stack: row.st ?? null,
      corrupted: row.cor ?? 0,
      extra: row.x ?? null,
      life: row.life ?? 0,
      fire: row.fire ?? 0,
      cold: row.cold ?? 0,
      lightning: row.lightning ?? 0,
      chaos: row.chaos ?? 0,
      phys: row.phys ?? "",
      mods: row.mods ?? null,
    };
  }
  const mods = row.mods || [];
  const life = num((mods.find((m) => /^\+\d+ to maximum Life/.test(m)) || "").replace(/^\+/, ""));
  const join = mods.join(" | ");
  return {
    ...row,
    armour: row.armour ?? 0,
    evasion: row.evasion ?? 0,
    es: row.es ?? 0,
    life,
    fire: resist(mods, ["Fire"]),
    cold: resist(mods, ["Cold"]),
    lightning: resist(mods, ["Lightning"]),
    chaos: num((mods.find((m) => /to Chaos Resistance/.test(m)) || "").replace(/^\+/, "")),
    dotMulti: num((join.match(/\+(\d+)% to Damage over Time Multiplier/) || [0, 0])[1]),
    physAdd: (join.match(/Adds (\d+) to (\d+) Physical Damage/) || [0, 0, 0]).slice(1, 3).map(Number),
  };
}

/** Age in minutes: the stored fetch time when present, file mtime only as a fallback. */
function ageMinutes(json, file) {
  const t = json && json.fetchedAt ? Date.parse(json.fetchedAt) : NaN;
  return (Date.now() - (Number.isFinite(t) ? t : statSync(file).mtimeMs)) / 60000;
}

if (cmd === "save") {
  if (!args.slot || !args.file) { console.error("save needs --slot and --file"); process.exit(2); }
  const payload = unwrap(readFileSync(args.file, "utf8"));
  // search.mjs returns { qid, total, idsAvailable, fetched, digest }, not `rows`;
  // derive() already normalises the compact digest rows.
  const rows = Array.isArray(payload) ? payload : (payload.rows ?? payload.digest);
  if (!Array.isArray(rows)) { console.error("no rows array in the input file"); process.exit(2); }
  const out = {
    fetchedAt: new Date().toISOString(),
    slot: args.slot,
    qid: payload && payload.qid,
    total: payload && payload.total,
    idsAvailable: payload && payload.idsAvailable,
    rows: rows.map(derive),
  };
  const file = join(dir, `${args.slot}.json`);
  writeFileSync(file, JSON.stringify(out, null, 1));
  console.log(`saved ${out.rows.length} rows (total ${out.total}) -> ${file}`);
  process.exit(0);
}

if (cmd === "list") {
  const files = readdirSync(dir).filter((f) => f.endsWith(".json"));
  for (const f of files) {
    const j = JSON.parse(readFileSync(join(dir, f), "utf8"));
    const age = ageMinutes(j, join(dir, f)).toFixed(1);
    console.log(`${f.padEnd(18)} ${String(j.rows.length).padStart(3)} rows  total ${j.total}  age ${age}min`);
  }
  process.exit(0);
}

if (cmd === "show") {
  if (!args.slot) {
    console.error("show needs --slot; run pool.mjs list to see the slots");
    process.exit(2);
  }
  const file = join(dir, `${args.slot}.json`);
  if (!existsSync(file)) { console.error(`no pool for ${args.slot}; search first`); process.exit(4); }
  const pool = JSON.parse(readFileSync(file, "utf8"));
  const maxAge = Number(args.max_age || 15);
  const ageMin = ageMinutes(pool, file);
  if (ageMin > maxAge) {
    console.error(`STALE: ${args.slot} pool is ${ageMin.toFixed(1)}min old (max ${maxAge}). Listing prices move; re-search or accept the risk explicitly.`);
    process.exit(4);
  }
  const isWeapon = pool.rows.some((r) => (r.pdps || 0) > 0 || (r.edps || 0) > 0);
  const key = args.sort || (isWeapon ? "pdps" : "life");
  const rows = [...pool.rows].sort((a, b) => Number(b[key] || 0) - Number(a[key] || 0)).slice(0, Number(args.limit || 15));
  console.log(`# ${args.slot} · total ${pool.total} · fetched ${pool.rows.length} · ${ageMin.toFixed(1)}min old · sorted by ${key}\n`);
  if (isWeapon) {
    console.log("price | item | base | pDPS | eDPS | phys range | aps | crit | q | ilvl | seller");
    for (const r of rows) {
      console.log(`${r.priceAmount ?? "–"}c | ${r.name} | ${r.base} | ${r.pdps || 0} | ${r.edps || 0} | ${r.pdmg || "–"} | ${r.aps || 0} | ${r.crit || 0} | ${r.quality ?? 0} | ${r.ilvl ?? "–"} | ${r.seller}`);
    }
  } else {
    console.log("price | item | base | armour | ev | es | life | res F/C/L | chaos | ilvl | seller");
    for (const r of rows) {
      console.log(`${r.priceAmount ?? "–"}c | ${r.name} | ${r.base} | ${r.armour} | ${r.evasion} | ${r.es || 0} | ${r.life} | ${r.fire}/${r.cold}/${r.lightning} | ${r.chaos} | ${r.ilvl ?? "–"} | ${r.seller}`);
    }
  }
  process.exit(0);
}

console.error(`unknown command: ${cmd}`);
process.exit(2);
