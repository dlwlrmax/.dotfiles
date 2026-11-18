#!/usr/bin/env node
// Build the browser-side expression for a trade search, and enforce the search
// spacing rule mechanically (mtime lock) so it cannot be violated by accident.
//
//   node scripts/search.mjs --league Covens --slot ring --spec specs/ring.json
//
// Prints a ready-to-paste `expression` argument for tools.browse.eval, plus the
// shell command that saves the result into the pool. Nothing here performs a
// request; only the browser does, from the user's logged-in session.
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const MIN_GAP_MS = 10_000;      // searches must be >= 10s apart
const BURST_WINDOW_MS = 30 * 60_000;
const BURST_MAX = 4;            // more than this in 30min needs --force

const args = {};
for (let i = 2; i < process.argv.length; i++) {
  const a = process.argv[i];
  if (a.startsWith("--")) {
    const k = a.slice(2).replace(/-/g, "_");
    const v = process.argv[i + 1] && !process.argv[i + 1].startsWith("--") ? process.argv[++i] : true;
    args[k] = v;
  }
}
const league = args.league;
const slot = args.slot;
const specPath = args.spec;
const maxIds = Number(args.max || 60);
if (!league || !slot || !specPath) {
  console.error("usage: search.mjs --league <L> --slot <slot> --spec <spec.json> [--max 60] [--force]");
  process.exit(2);
}

const dir = join(homedir(), "pob", "pool", league);
mkdirSync(dir, { recursive: true });
const gapFile = join(dir, ".lastsearch");
const logFile = join(dir, ".searchlog");
const readIf = (p) => (existsSync(p) ? readFileSync(p, "utf8") : "");

const now = Date.now();
if (!args.force && existsSync(gapFile)) {
  const last = Number(readFileSync(gapFile, "utf8").trim()) || 0;
  const wait = MIN_GAP_MS - (now - last);
  if (wait > 0) {
    console.error(`BLOCKED: last search was ${((now - last) / 1000).toFixed(1)}s ago. Wait ${Math.ceil(wait / 1000)}s, then rerun.`);
    process.exit(3);
  }
}
if (!args.force && existsSync(logFile)) {
  const stamps = readFileSync(logFile, "utf8").split("\n").filter(Boolean).map(Number);
  const recent = stamps.filter((t) => now - t < BURST_WINDOW_MS);
  if (recent.length >= BURST_MAX) {
    console.error(`BLOCKED: ${recent.length} searches in the last 30min (cap ${BURST_MAX}). Spend a fetch or read a cached pool instead; --force to override.`);
    process.exit(3);
  }
}

const spec = JSON.parse(readFileSync(specPath, "utf8"));
const query = {
  query: {
    status: { option: spec.status || "securable" },   // instant buyout only
    ...(spec.term ? { term: spec.term } : {}),
    filters: spec.filters || {},
    ...(spec.stats ? { stats: spec.stats } : {}),
  },
  sort: spec.sort || { price: "asc" },
};

// Reserve the slot before emitting, so a failed run still counts.
writeFileSync(gapFile, String(now));
writeFileSync(logFile, [...readIf(logFile).split("\n").filter(Boolean), String(now)].join("\n") + "\n");

const page = `(async function () {
  window.__p = { qid: null, ids: [], rows: [], total: null };
  var r = await fetch("/api/trade/search/${league}", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(${JSON.stringify(query)})
  });
  var sj = await r.json();
  if (sj.error) return JSON.stringify({ err: sj.error });
  window.__p.qid = sj.id;
  window.__p.total = sj.total;
  window.__p.ids = sj.result || [];
  var take = Math.min(window.__p.ids.length, ${maxIds});
  for (var i = 0; i < take; i += 10) {
    var chunk = window.__p.ids.slice(i, i + 10);
    var fj = await (await fetch("/api/trade/fetch/" + chunk.join(",") + "?query=" + encodeURIComponent(sj.id))).json();
    window.__p.rows = window.__p.rows.concat(fj.result || []);
  }
  var clean = function (s) { return String(s && s.description !== undefined ? s.description : s).replace(/\\[([^\\]|]*)\\|([^\\]]*)\\]/g, "$2"); };
  var rows = window.__p.rows.map(function (i) {
    var mods = [].concat(i.item.implicitMods || [], i.item.explicitMods || []).map(clean);
    var props = {};
    (i.item.properties || []).forEach(function (p) { props[p.name] = p.values[0][0]; });
    return {
      name: i.item.name,
      base: i.item.baseType,
      price: i.listing && i.listing.price ? i.listing.price.amount + " " + i.listing.price.currency : null,
      priceAmount: i.listing && i.listing.price ? i.listing.price.amount : null,
      seller: i.listing && i.listing.account ? i.listing.account.name : null,
      armour: props["Armour"] ? Number(String(props["Armour"]).replace(/[^0-9]/g, "")) : 0,
      evasion: props["Evasion Rating"] ? Number(String(props["Evasion Rating"]).replace(/[^0-9]/g, "")) : 0,
      quality: props["Quality"] || null,
      requirements: (i.item.requirements || []).map(function (r) { return r.name + " " + r.values[0][0]; }),
      mods: mods
    };
  });
  window.__p.full = function (indexes) {
    return JSON.stringify(indexes.map(function (n) { return rows[n]; }));
  };
  // The compact digest is what travels back through the model: 60 full rows (~30KB)
  // would not survive, and only the chosen few need their mod text.
  var sum = function (text, re) { var s = 0, x, rr = new RegExp(re, "g"); while ((x = rr.exec(text)) !== null) { s += Number(x[1]); } return s; };
  var digest = rows.map(function (r) {
    var t = (r.mods || []).join(" | ");
    var one = function (re) { var m = new RegExp(re).exec(t); return m ? Number(m[1]) : 0; };
    var elemAll = sum(t, "[+](\\\\d+)% to all Elemental Resistances");
    return {
      n: r.name, b: r.base, p: r.priceAmount, seller: r.seller, ar: r.armour,
      life: one("[+](\\\\d+) to maximum Life"),
      fire: one("[+](\\\\d+)% to Fire Resistance") + elemAll + sum(t, "[+](\\\\d+)% to Fire and (?:Cold|Lightning)"),
      cold: one("[+](\\\\d+)% to Cold Resistance") + elemAll + sum(t, "[+](\\\\d+)% to Cold and (?:Fire|Lightning)") + sum(t, "[+](\\\\d+)% to Fire and Cold"),
      lightning: one("[+](\\\\d+)% to Lightning Resistance") + elemAll + sum(t, "[+](\\\\d+)% to (?:Fire|Cold) and Lightning"),
      chaos: one("[+](\\\\d+)% to Chaos Resistance"),
      phys: (t.match(/Adds (\\d+) to (\\d+) Physical Damage/) || [0, 0, 0]).slice(1, 3).join("-")
    };
  });
  return JSON.stringify({ qid: window.__p.qid, total: window.__p.total, idsAvailable: window.__p.ids.length, fetched: rows.length, digest: digest });
})()`;

console.log("=== expression (paste verbatim as the browse.eval `expression` argument)");
console.log(JSON.stringify(page));
console.log("");
console.log("=== full mod text for chosen rows lives in the page: paste this as a second browse.eval expression");
console.log('window.__p.full([0,1,2])');
console.log("");
console.log("=== then save the returned rows to the pool");
console.log(`node scripts/pool.mjs save --league ${league} --slot ${slot} --file /tmp/opencode/${slot}-rows.json`);
