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

const delta = (a, b) => (a === null || b === null ? null : b - a);
const signed = (v) => (v === null ? "–" : (v > 0 ? "+" : "") + v);
const pct = (a, b) => (a ? signed(Math.round(((b / a) - 1) * 1000) / 10) + "%" : "–");

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
const uncapped = ELEM.filter((e) => pickSet[e].total !== null && pickSet[e].cap !== null && pickSet[e].total < pickSet[e].cap);
const thin = ELEM.filter((e) => pickSet[e].overcap !== null && pickSet[e].overcap < OVERCAP_TARGET);
console.log(`- res caps (${pick}): ${uncapped.length ? "**FAIL** " + uncapped.map((e) => `${e} ${pickSet[e].total}<${pickSet[e].cap}`).join(", ") : "all elements capped"}`);
console.log(`- overcap >= ${OVERCAP_TARGET} (${pick}): ${thin.length ? "**thin** " + thin.map((e) => `${e} +${pickSet[e].overcap}`).join(", ") : "ok"}`);
console.log(`- chaos (${pick}): ${pickSet.chaos.total} (informational; negative is normal)`);

console.log("\n## Sets\n");
console.log("| Set | Cost | Life | EHP | Armour | DPS | BleedDPS | Overcap F/C/L | Chaos |");
console.log("|---|---|---|---|---|---|---|---|---|");
for (const label of labels) {
  const s = data[label];
  const oc = ELEM.map((e) => signed(s[e].overcap)).join(" / ");
  const bad = ELEM.filter((e) => s[e].total !== null && s[e].cap !== null && s[e].total < s[e].cap);
  const thinSet = ELEM.filter((e) => s[e].overcap !== null && s[e].overcap < OVERCAP_TARGET);
  const flag = bad.length ? ` ⚠uncapped(${bad.join(",")})` : thinSet.length ? ` ⚠thin(${thinSet.join(",")})` : "";
  console.log(
    `| ${label}${label === pick ? " **(pick)**" : ""}${flag} | ${s.cost ?? "–"} | ${signed(delta(base.life, s.life))} | ` +
      `${signed(delta(base.ehp, s.ehp))} (${pct(base.ehp, s.ehp)}) | ${signed(delta(base.armour, s.armour))} | ` +
      `${signed(delta(base.dps, s.dps))} (${pct(base.dps, s.dps)}) | ${signed(delta(base.bleedDps, s.bleedDps))} | ${oc} | ${s.chaos.total} |`
  );
}

console.log(`\n## Res before / after (${pick})\n`);
console.log("| Res | Trước total / cap / overcap | Sau total / cap / overcap | Δ overcap |");
console.log("|---|---|---|---|");
for (const e of SET_KEYS) {
  const b = base[e], a = pickSet[e];
  const bTxt = `${b.total} / ${b.cap ?? "–"} / ${b.overcap === null ? "–" : (b.overcap > 0 ? "+" : "") + b.overcap}`;
  const aTxt = `${a.total} / ${a.cap ?? "–"} / ${a.overcap === null ? "–" : (a.overcap > 0 ? "+" : "") + a.overcap}`;
  const anyB = b.overcap === null ? b.total : b.overcap;
  const anyA = a.overcap === null ? a.total : a.overcap;
  console.log(`| ${e[0].toUpperCase() + e.slice(1)} | ${bTxt} | ${aTxt} | ${signed(anyA - anyB)} |`);
}

console.log(`\n_bleed chance ${pickSet.bleedChance}% · baseline life ${base.life} · base DPS ${base.dps}_`);
