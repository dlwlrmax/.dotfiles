#!/usr/bin/env node
// Render the sim output as the report tables, and run the mechanical gates:
// resistance caps, overcap >= 20, and attribute requirements. Prints markdown.
//
//   node scripts/table.mjs --pick A < /tmp/opencode/sim-out.json
//
// Input is the raw return value of the sim program, double-encoded or not.
import { readFileSync } from "node:fs";

const argv = process.argv.slice(2);
const args = {};
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a.startsWith("--")) {
    const k = a.slice(2).replace(/-/g, "_");
    args[k] = argv[i + 1] && !argv[i + 1].startsWith("--") ? argv[++i] : true;
  }
}
const raw = args.file ? readFileSync(args.file, "utf8") : readFileSync(0, "utf8");
let data = raw;
for (let i = 0; i < 4 && typeof data === "string"; i++) {
  try { data = JSON.parse(data); } catch { break; }
}
if (!data || typeof data !== "object" || !data.base) {
  console.error("could not read sim output: expected an object with a `base` key");
  process.exit(2);
}

const SET_KEYS = ["fire", "cold", "lightning", "chaos"];
const ELEM = ["fire", "cold", "lightning"];
const OVERCAP_TARGET = 20;

// Capped can only be judged from Missing<El>Resist: the baseline `FireResist` value is
// clamped to the cap, so a build 1% short of the cap reads as "capped" there.
const short = (s, e) => (s[e].missing ?? 0) > 0;
const thinOf = (s) => ELEM.filter((e) => !short(s, e) && (s[e].overcap ?? 0) < OVERCAP_TARGET);
const shortOf = (s) => ELEM.filter((e) => short(s, e));

const delta = (a, b) => (a === null || b === null ? null : b - a);
const signed = (v) => (v === null ? "–" : (v > 0 ? "+" : "") + v);
const pct = (a, b) => (a ? signed(Math.round(((b / a) - 1) * 1000) / 10) + "%" : "–");
const ocTxt = (s, e) => (short(s, e) ? `⚠short ${s[e].missing}` : signed(s[e].overcap));

const labels = Object.keys(data).filter((k) => !["build", "own", "reqs", "base"].includes(k));
const base = data.base;
const pick = args.pick && data[args.pick] ? args.pick : labels[labels.length - 1];

console.log("## Gate\n");
const badReqs = Object.entries(data.reqs || {}).filter(([, r]) => !r || r.error || !r.ok);
console.log(
  `- attributes: ${badReqs.length ? "**FAIL** " + badReqs.map(([k]) => k).join(", ") : "pass"} ` +
    `(build Str ${data.own.Str} / Dex ${data.own.Dex} / Int ${data.own.Int})`
);
if (badReqs.length) {
  for (const [k, r] of badReqs) console.log(`  - ${k}: ${r && r.error ? r.error : `needs S${r.str} D${r.dex} I${r.int}`}`);
}
const pickSet = data[pick];
const shortPick = shortOf(pickSet);
const thinPick = thinOf(pickSet);
console.log(`- res caps (${pick}): ${shortPick.length ? "**FAIL** " + shortPick.map((e) => `${e} short ${pickSet[e].missing}`).join(", ") : "all elements capped"}`);
console.log(`- overcap >= ${OVERCAP_TARGET} (${pick}): ${thinPick.length ? "**thin** " + thinPick.map((e) => `${e} +${pickSet[e].overcap}`).join(", ") : "ok"}`);
console.log(`- chaos (${pick}): total ${pickSet.chaos.total}, still short ${pickSet.chaos.missing} of the cap (informational; negative is normal)`);

console.log("\n## Sets\n");
console.log("| Set | Cost | Life | EHP | Armour | DPS | BleedDPS | Overcap F/C/L | Chaos |");
console.log("|---|---|---|---|---|---|---|---|---|");
for (const label of labels) {
  const s = data[label];
  const oc = ELEM.map((e) => ocTxt(s, e)).join(" / ");
  const bad = shortOf(s);
  const thinSet = thinOf(s);
  const flag = bad.length ? ` ⚠uncapped(${bad.map((e) => `${e} short ${s[e].missing}`).join(",")})` : thinSet.length ? ` ⚠thin(${thinSet.join(",")})` : "";
  console.log(
    `| ${label}${label === pick ? " **(pick)**" : ""}${flag} | ${s.cost ?? "–"} | ${signed(delta(base.life, s.life))} | ` +
      `${signed(delta(base.ehp, s.ehp))} (${pct(base.ehp, s.ehp)}) | ${signed(delta(base.armour, s.armour))} | ` +
      `${signed(delta(base.dps, s.dps))} (${pct(base.dps, s.dps)}) | ${signed(delta(base.bleedDps, s.bleedDps))} | ${oc} | ${s.chaos.total} |`
  );
}

console.log(`\n## Res before / after (${pick})\n`);
console.log("| Res | Trước total / overcap | Sau total / overcap | Δ |");
console.log("|---|---|---|---|");
for (const e of SET_KEYS) {
  const b = base[e], a = pickSet[e];
  const txt = (x) => `${x.total} / ${short({ [e]: x }, e) ? `short ${x.missing}` : signed(x.overcap)}`;
  const change = e === "chaos" ? (a.total ?? 0) - (b.total ?? 0) : short(pickSet, e) || short(base, e) ? (a.total ?? 0) - (b.total ?? 0) : (a.overcap ?? 0) - (b.overcap ?? 0);
  console.log(`| ${e[0].toUpperCase() + e.slice(1)} | ${txt(b)} | ${txt(a)} | ${signed(change)} |`);
}

console.log(`\n_bleed chance ${pickSet.bleedChance}% · baseline life ${base.life} · base DPS ${base.dps}_`);
