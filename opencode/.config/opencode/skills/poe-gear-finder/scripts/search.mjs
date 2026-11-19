#!/usr/bin/env node
// Build the browser-side expression for a trade search, and enforce the search
// spacing rule mechanically (mtime lock) so it cannot be violated by accident.
//
//   node scripts/search.mjs --league Covens --slot ring --spec specs/ring.json
//
// Prints a ready-to-paste `expression` argument for tools.browse.eval, plus the
// shell command that saves the result into the pool. Nothing here performs a
// request; only the browser does, from the user's logged-in session.
import { readFileSync, writeFileSync, mkdirSync, existsSync, unlinkSync } from "node:fs";
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

// --unmark: release the most recent reservation. A failed paste otherwise burns one of
// the four 30-min slots with no recourse short of --force. Emits no expression, makes no
// request, and bypasses the gates because it only edits the bookkeeping files.
if (args.unmark) {
  if (!league) {
    console.error("usage: search.mjs --unmark --league <L>");
    process.exit(2);
  }
  const uDir = join(homedir(), "pob", "pool", league);
  const uGap = join(uDir, ".lastsearch");
  const uLog = join(uDir, ".searchlog");
  const stamps = (existsSync(uLog) ? readFileSync(uLog, "utf8") : "").split("\n").filter(Boolean);
  if (!stamps.length) {
    console.log(`nothing to unmark: ${uLog} holds no stamps`);
    process.exit(0);
  }
  const removed = stamps.pop();
  if (stamps.length) {
    writeFileSync(uLog, stamps.join("\n") + "\n");
    writeFileSync(uGap, stamps[stamps.length - 1]);
  } else {
    unlinkSync(uLog);
    if (existsSync(uGap)) unlinkSync(uGap);
  }
  console.log(
    `unmarked ${new Date(Number(removed)).toISOString()} (${stamps.length} stamp(s) left in ${league})`
  );
  process.exit(0);
}

if (!league || !slot || !specPath) {
  console.error("usage: search.mjs --league <L> --slot <slot> --spec <spec.json> [--max 60] [--force] [--reuse] [--unmark]");
  process.exit(2);
}

const dir = join(homedir(), "pob", "pool", league);
mkdirSync(dir, { recursive: true });
const gapFile = join(dir, ".lastsearch");
const logFile = join(dir, ".searchlog");
const readIf = (p) => (existsSync(p) ? readFileSync(p, "utf8") : "");

const now = Date.now();
if (!args.reuse && !args.force && existsSync(gapFile)) {
  const last = Number(readFileSync(gapFile, "utf8").trim()) || 0;
  const wait = MIN_GAP_MS - (now - last);
  if (wait > 0) {
    console.error(`BLOCKED: last search was ${((now - last) / 1000).toFixed(1)}s ago. Wait ${Math.ceil(wait / 1000)}s, then rerun.`);
    process.exit(3);
  }
}
if (!args.reuse && !args.force && existsSync(logFile)) {
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

// Reserve the slot before emitting, so a failed run still counts. --reuse only re-reads the
// ids already stored in the tab (a fetch), so it spends no search and skips the gates —
// that is the retry path after a mapping bug or a closed tab.
if (!args.reuse) {
  writeFileSync(gapFile, String(now));
  writeFileSync(logFile, [...readIf(logFile).split("\n").filter(Boolean), String(now)].join("\n") + "\n");
}

const head = args.reuse
  ? `window.__p = window.__p || { rows: [] };
  var sj = { id: window.__p.qid, total: window.__p.total, result: window.__p.ids || [] };
  if (!sj.id) return JSON.stringify({ err: "no stored query in this tab — run a search first" });
  window.__p.rows = [];`
  : `window.__p = { qid: null, ids: [], rows: [], total: null };
  var r = await fetch("/api/trade/search/" + LEAGUE, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(${JSON.stringify(query)})
  });
  var sj = await r.json();
  if (sj.error) return JSON.stringify({ err: sj.error });
  window.__p.qid = sj.id;
  window.__p.total = sj.total;
  window.__p.ids = sj.result || [];`;

const page = `(async function () {
  var LEAGUE = ${JSON.stringify(league)};
  ${head}
  var take = Math.min(window.__p.ids.length, ${maxIds});
  for (var i = 0; i < take; i += 10) {
    var chunk = window.__p.ids.slice(i, i + 10);
    var fj = await (await fetch("/api/trade/fetch/" + chunk.join(",") + "?query=" + encodeURIComponent(sj.id))).json();
    window.__p.rows = window.__p.rows.concat(fj.result || []);
  }
  var clean = function (s) { return String(s && s.description !== undefined ? s.description : s).replace(/\\[([^\\]|]*)\\|([^\\]]*)\\]/g, "$2"); };
  var n0 = function (v) { var m = /(\\d+(?:\\.\\d+)?)/.exec(String(v === null || v === undefined ? "" : v)); return m ? Number(m[1]) : 0; };
  var KNOWN = ["Armour", "Evasion Rating", "Energy Shield", "Quality", "Physical Damage",
    "Attacks per Second", "Elemental Damage", "Critical Strike Chance", "Item Level", "Stack Size", "Sockets"];
  var rows = window.__p.rows.map(function (i) {
    var mods = [].concat(i.item.implicitMods || [], i.item.explicitMods || []).map(clean);
    var props = {};
    (i.item.properties || []).forEach(function (p) { if (p.values && p.values[0]) props[p.name] = p.values[0][0]; });
    var extra = {};
    Object.keys(props).forEach(function (k) { if (KNOWN.indexOf(k) < 0) extra[k] = props[k]; });
    return {
      name: i.item.name,
      base: i.item.baseType,
      price: i.listing && i.listing.price ? i.listing.price.amount + " " + i.listing.price.currency : null,
      priceAmount: i.listing && i.listing.price ? i.listing.price.amount : null,
      seller: i.listing && i.listing.account ? i.listing.account.name : null,
      armour: n0(props["Armour"]), evasion: n0(props["Evasion Rating"]), es: n0(props["Energy Shield"]),
      pdmg: props["Physical Damage"] || null,
      aps: props["Attacks per Second"] || null,
      edmg: props["Elemental Damage"] || null,
      crit: props["Critical Strike Chance"] || null,
      quality: props["Quality"] || null,
      ilvl: n0(props["Item Level"]),
      stack: n0(props["Stack Size"]),
      sockets: props["Sockets"] || null,
      corrupted: i.item.corrupted ? 1 : 0,
      extra: Object.keys(extra).length ? extra : null,
      requirements: (i.item.requirements || []).map(function (r) { return r.name + " " + r.values[0][0]; }),
      mods: mods
    };
  });
  window.__p.full = function (indexes) {
    return JSON.stringify(indexes.map(function (n) { return rows[n]; }));
  };
  // One digest shape for every item class: generic defensives, weapon numbers when the
  // item has them, and an "x" map for any property not named above (flask charges, gem
  // lines, stack sizes...). 60 full rows with mod text is ~30KB and would not survive the
  // trip back through the model; full text stays in the page for window.__p.full([...]).
  var sum = function (text, re) { var s = 0, x, rr = new RegExp(re, "g"); while ((x = rr.exec(text)) !== null) { s += Number(x[1]); } return s; };
  var range = function (v) { var m = /(\\d+(?:\\.\\d+)?)-(\\d+(?:\\.\\d+)?)/.exec(String(v || "")); return m ? (Number(m[1]) + Number(m[2])) / 2 : 0; };
  var digest = rows.map(function (r) {
    var t = (r.mods || []).join(" | ");
    var one = function (re) { var m = new RegExp(re).exec(t); return m ? Number(m[1]) : 0; };
    var elemAll = sum(t, "[+](\\\\d+)% to all Elemental Resistances");
    var apsN = parseFloat(r.aps || "") || 0;
    return {
      n: r.name, b: r.base, p: r.priceAmount, seller: r.seller,
      ar: r.armour, ev: r.evasion, es: r.es,
      pdps: Math.round(range(r.pdmg) * apsN), edps: Math.round(range(r.edmg) * apsN),
      aps: apsN, crit: n0(r.crit), pdmg: r.pdmg, edmg: r.edmg,
      q: n0(r.quality), ilvl: r.ilvl, soc: r.sockets, st: r.stack, cor: r.corrupted, x: r.extra,
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

// Self-check before printing: escaping bugs in the emitted page code (a stray backtick,
// a bad regex escape) would only surface in the browser, as a silent wrong result.
{
  const { execFileSync } = await import("node:child_process");
  const { mkdtempSync, writeFileSync } = await import("node:fs");
  const { tmpdir } = await import("node:os");
  const { join } = await import("node:path");
  const check = join(mkdtempSync(join(tmpdir(), "pobsearch-")), "check.mjs");
  writeFileSync(check, "async function __r() {\nconst x = " + JSON.stringify(page) + ";\nreturn x;\n}\n");
  try {
    execFileSync("node", ["--check", check], { stdio: "pipe" });
    console.error("expression syntax check: ok");
  } catch (e) {
    console.error("SYNTAX CHECK FAILED — do not paste this expression:");
    console.error(String(e.stderr || e.message).slice(0, 400));
    process.exit(1);
  }
}

console.log("=== expression (paste verbatim as the browse.eval `expression` argument)");
// Emit the literal in chunks joined with `+` so no line exceeds a reader's per-line
// limit: string literals concatenate, so the pasted value is byte-identical.
{
  const pieces = [];
  for (let i = 0; i < page.length; i += 1400) pieces.push(JSON.stringify(page.slice(i, i + 1400)));
  console.log(pieces.join(" +\n"));
}
console.log("");
console.log("=== full mod text for chosen rows lives in the page: paste this as a second browse.eval expression");
console.log('window.__p.full([0,1,2])');
console.log("");
console.log("=== then save the returned rows to the pool");
console.log(`node scripts/pool.mjs save --league ${league} --slot ${slot} --file /tmp/opencode/${slot}-rows.json`);
