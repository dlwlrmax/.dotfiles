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
if (!sj.id) { return JSON.stringify({ err: "no stored query in this tab — run a search first" }) }
window.__p.rows = [];`
  : `window.__p = { qid: null, ids: [], rows: [], total: null };
var r = await fetch("/api/trade/search/" + LEAGUE, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(${JSON.stringify(query)}) });
var sj = await r.json();
if (sj.error) { return JSON.stringify({ err: sj.error }) }
window.__p.qid = sj.id; window.__p.total = sj.total; window.__p.ids = sj.result || [];`;

// One digest shape for every item class: generic defensives, weapon numbers when the item
// has them, and an "x" map for any property not named above (flask charges, gem lines,
// stack sizes...). 60 full rows with mod text is ~30KB and would not survive the trip back
// through the model; the mod text stays in the page for window.__p.full([...]).
const page = `(async function () {
var LEAGUE = ${JSON.stringify(league)};
${head}
var P = window.__p, ids = P.ids || [], take = Math.min(ids.length, ${maxIds});
for (var i = 0; i < take; i += 10) {
var ch = ids.slice(i, i + 10);
P.rows = P.rows.concat((await (await fetch("/api/trade/fetch/" + ch.join(",") + "?query=" + encodeURIComponent(sj.id))).json()).result || []);
}
var tx=function(s){return String(s&&s.description!==undefined?s.description:s).replace(/\\[([^\\]|]*)\\|([^\\]]*)\\]/g,"$2")};
var n0=function(v){var m=/(\\d+(?:\\.\\d+)?)/.exec(String(v==null?"":v));return m?Number(m[1]):0};
var K="|Armour|Evasion Rating|Energy Shield|Quality|Physical Damage|Attacks per Second|Elemental Damage|Critical Strike Chance|Item Level|Stack Size|Sockets|";
var sm=function(t,re){var s=0,x,r=new RegExp(re,"g");while((x=r.exec(t))!==null){s+=Number(x[1])}return s};
var rg=function(v){var m=/(\\d+(?:\\.\\d+)?)-(\\d+(?:\\.\\d+)?)/.exec(String(v||""));return m?(Number(m[1])+Number(m[2]))/2:0};
var mods=function(it){return [].concat(it.implicitMods||[],it.explicitMods||[]).map(tx)};
var digest=P.rows.map(function(it0){
var it=it0.item,l=it0.listing||{},pr=l.price||null,pq={};
(it.properties||[]).forEach(function(p){if(p.values&&p.values[0]){pq[p.name]=p.values[0][0]}});
var ex=null,k;
for(k in pq){if(K.indexOf("|"+k+"|")<0){ex=ex||{};ex[k]=pq[k]}}
var mm=mods(it),t=mm.join(" | "),res={F:0,C:0,L:0,X:0},at={S:0,D:0,I:0};
var one=function(re){var m=new RegExp(re).exec(t);return m?Number(m[1]):0};
mm.forEach(function(m){var g=/[+](\\d+)% to (.*Resistance)/.exec(m);if(!g){return}var v=Number(g[1]),w=g[2];if(/all Elemental/.test(w)){res.F+=v;res.C+=v;res.L+=v}if(/Fire/.test(w)){res.F+=v}if(/Cold/.test(w)){res.C+=v}if(/Lightning/.test(w)){res.L+=v}if(/Chaos/.test(w)){res.X+=v}});
mm.forEach(function(m){var g=/[+](\\d+) to (all attributes|.*Strength.*|.*Dexterity.*|.*Intelligence.*)/.exec(m);if(!g){return}var v=Number(g[1]),w=g[2];if(/all attributes/.test(w)){at.S+=v;at.D+=v;at.I+=v}if(/Strength/.test(w)){at.S+=v}if(/Dexterity/.test(w)){at.D+=v}if(/Intelligence/.test(w)){at.I+=v}});
var an=parseFloat(pq["Attacks per Second"]||"")||0;
return {
n:it.name,b:it.baseType,p:pr?pr.amount:null,seller:l.account?l.account.name:null,
req:(it.requirements||[]).map(function(r){return r.name+" "+r.values[0][0]}).join(" "),
ar:n0(pq["Armour"]),ev:n0(pq["Evasion Rating"]),es:n0(pq["Energy Shield"]),
pdps:Math.round(rg(pq["Physical Damage"])*an),edps:Math.round(rg(pq["Elemental Damage"])*an),
aps:an,crit:n0(pq["Critical Strike Chance"]),pdmg:pq["Physical Damage"]||null,edmg:pq["Elemental Damage"]||null,
q:n0(pq["Quality"]),ilvl:n0(pq["Item Level"]),soc:pq["Sockets"]||null,st:n0(pq["Stack Size"]),cor:it.corrupted?1:0,x:ex,
life:one("[+](\\\\d+) to maximum Life"),
dotMulti:sm(t,"[+](\\\\d+)% to (?:Physical )?Damage over Time Multiplier"),
faster:one("Bleeding you inflict deals Damage (\\\\d+)% Faster"),
manaCraft:one("[-](\\\\d+) to Mana Cost"),
fire:res.F,cold:res.C,lightning:res.L,chaos:res.X,
str:at.S,dex:at.D,int:at.I,
phys:(t.match(/Adds (\\d+) to (\\d+) Physical Damage/)||[0,0,0]).slice(1,3).join("-")
};
});
P.full=function(ix){return JSON.stringify(ix.map(function(n){var i=P.rows[n],it=i.item,l=i.listing||{},pr=l.price||null;return {name:it.name,base:it.baseType,price:pr?pr.amount+" "+pr.currency:null,priceAmount:pr?pr.amount:null,seller:l.account?l.account.name:null,mods:mods(it)}}))};
window.__p.top = function (n, key, asc) { var a = digest.map(function (d, i) { return { d: d, i: i }; }).sort(function (x, y) { return (Number(y.d[key]) || 0) - (Number(x.d[key]) || 0); }); if (asc) { a.reverse(); } return JSON.stringify(a.slice(0, n).map(function (z) { return { i: z.i, n: z.d.n, b: z.d.b, p: z.d.p, seller: z.d.seller, v: z.d[key] }; })); };
return JSON.stringify({qid:P.qid,total:P.total,idsAvailable:ids.length,fetched:P.rows.length,digest:digest});
})()`;

// Self-check before printing: escaping bugs in the emitted page code (a stray backtick,
// a bad regex escape) would only surface in the browser, as a silent wrong result.
{
  const { execFileSync } = await import("node:child_process");
  const { mkdtempSync, writeFileSync, rmSync } = await import("node:fs");
  const { tmpdir } = await import("node:os");
  const { join } = await import("node:path");
  const tmp = mkdtempSync(join(tmpdir(), "pobsearch-"));
  const check = join(tmp, "check.mjs");
  // The page is an async IIFE expression: valid as a statement inside a function body.
  // Checking the page itself (not a JSON literal of it) catches regex/escape breakage.
  writeFileSync(check, "async function __run() {\n" + page + "\n}\n");
  try {
    execFileSync("node", ["--check", check], { stdio: "pipe" });
    console.error("expression syntax check: ok");
  } catch (e) {
    console.error("SYNTAX CHECK FAILED — do not paste this expression:");
    console.error(String(e.stderr || e.message).slice(0, 400));
    process.exit(1);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

console.log("=== expression (paste verbatim as the browse.eval `expression` argument)");
// Emit `eval("chunk" + "chunk" ...)`: browse.eval returns the value of a pasted
// string-producing expression, so the page code has to be eval'd to run. Chunks keep
// every line short; string literals concatenate, so the eval'd value is byte-identical.
{
  const pieces = [];
  for (let i = 0; i < page.length; i += 1400) pieces.push(JSON.stringify(page.slice(i, i + 1400)));
  console.log("eval(" + pieces.join(" +\n") + ")");
}
console.log("");
console.log("=== second browse.eval expressions on the same tab (no request, page already holds the rows)");
console.log('window.__p.top(10, "life")     // rank digest rows by any digest key, highest first (3rd truthy arg = ascending)');
console.log('window.__p.full([0,1,2])       // full row + mod text for the chosen digest indexes');
console.log("");
console.log("=== then save the returned rows to the pool");
console.log(`node scripts/pool.mjs save --league ${league} --slot ${slot} --file /tmp/opencode/${slot}-rows.json`);
