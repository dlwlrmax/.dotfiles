#!/usr/bin/env node
// Emit a complete, ready-to-paste code-mode program that simulates every gear set
// in PoB, snapshots the stats and resistances, and checks attribute requirements.
// The model never hand-writes the sim code, so escaping cannot bite.
//
//   node scripts/sim.mjs --build current.xml --items items.json --sets sets.json > /tmp/opencode/sim.js
//
// items.json: { "<key>": { "name": "...", "base": "...", "mods": ["..."], "rarity": "RARE",
//                          "quality": 0, "price": 3 } }   quality/price optional
// sets.json:  { "<label>": { "cost": 67, "Helmet": "<key>", "Belt": "<key>", ... } }
//             slot names are PoB's: Helmet Gloves Belt "Ring 1" "Ring 2" Boots Body Armour
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
if (!args.items || !args.sets) {
  console.error("usage: sim.mjs --build <build.xml> --items items.json --sets sets.json");
  process.exit(2);
}
const build = args.build || "current.xml";
const items = JSON.parse(readFileSync(args.items, "utf8"));
const sets = JSON.parse(readFileSync(args.sets, "utf8"));

// A typo'd key used to be skipped silently, so the set looked cheaper/weaker with no
// explanation. Fail loudly, across every set, before anything is emitted.
const unknown = [];
for (const [label, set] of Object.entries(sets)) {
  for (const [slot, key] of Object.entries(set)) {
    if (slot === "cost" || items[key]) continue;
    unknown.push(`${key} (in set "${label}", slot "${slot}")`);
  }
}
if (unknown.length) {
  console.error("unknown item key(s) referenced by sets.json:");
  for (const u of unknown) console.error("  - " + u);
  console.error(`known keys: ${Object.keys(items).join(", ") || "(none)"}`);
  process.exit(1);
}

// Build each item's PoB text here; no Implicits header, implicits are ordinary mods.
const texts = {};
const meta = {};
for (const [key, it] of Object.entries(items)) {
  const head = [`Rarity: ${it.rarity || "RARE"}`, it.name, it.base, "--------", `Item Level: ${it.ilvl || 85}`];
  if (it.quality !== undefined && it.quality !== null) head.push(`Quality: ${it.quality}`);
  head.push("--------");
  texts[key] = head.concat(it.mods).join("\n");
  meta[key] = { name: it.name, base: it.base, price: it.price ?? null };
}

const program = `const ITEMS = ${JSON.stringify(texts, null, 2)};
const SETS = ${JSON.stringify(sets, null, 2)};
const BUILD = ${JSON.stringify(build)};
const ITEM_META = ${JSON.stringify(meta, null, 2)};

const g = (t, k) => { const m = t.match(new RegExp(k + ":\\\\s*(-?[\\\\d.]+)")); return m ? +m[1] : null; };
const n = (t, k) => { const m = t.match(new RegExp('"' + k + '":\\\\s*(-?[\\\\d.]+)')); return m ? +m[1] : null; };

const snap = async () => {
  const a = String(await tools.pob.lua_get_stats({}));
  const res = String(await tools.pob.export_full_stats({ filter: "Resist" }));
  const bleed = String(await tools.pob.export_full_stats({ filter: "Bleed" }));
  // The cap must come from Missing<El>Resist, never from lua_get_stats: that value is
  // already clamped to the cap, so a build 1% short reads as "capped" there.
  const r = (el) => ({
    total: n(res, el + "ResistTotal"),
    overcap: n(res, el + "ResistOverCap"),
    missing: n(res, "Missing" + el + "Resist"),
  });
  return {
    life: g(a, "Life"),
    mana: g(a, "ManaUnreserved"),
    ehp: g(a, "TotalEHP") === null ? null : Math.round(g(a, "TotalEHP")),
    armour: g(a, "Armour") === null ? null : Math.round(g(a, "Armour")),
    dps: g(a, "CombinedDPS") === null ? null : Math.round(g(a, "CombinedDPS")),
    bleedDps: n(bleed, "BleedDPS") === null ? null : Math.round(n(bleed, "BleedDPS")),
    bleedChance: n(bleed, "BleedChance"),
    fire: r("Fire"), cold: r("Cold"), lightning: r("Lightning"), chaos: r("Chaos"),
  };
};

await tools.pob.lua_load_build({ build_name: BUILD });

// Gate: attribute requirements, checked on the build as loaded.
const own = {};
for (const k of ["Str", "Dex", "Int"]) {
  const s = String(await tools.pob.export_full_stats({ filter: k }));
  own[k] = n(s, k);
}
const reqs = {};
for (const [key, text] of Object.entries(ITEMS)) {
  try {
    const p = String(await tools.pob.parse_item({ text }));
    const m = p.match(/"requirements":\\s*\\{[^}]*\\}/);
    const req = m ? JSON.parse("{" + m[0] + "}").requirements : null;
    reqs[key] = req ? {
      str: req.str || 0, dex: req.dex || 0, int: req.int || 0, level: req.level || 0,
      ok: (req.str || 0) <= own.Str && (req.dex || 0) <= own.Dex && (req.int || 0) <= own.Int,
    } : null;
  } catch (e) {
    reqs[key] = { error: String(e).slice(0, 80) };
  }
}

const out = { build: BUILD, own, reqs, items: ITEM_META, base: await snap() };
for (const [label, set] of Object.entries(SETS)) {
  await tools.pob.lua_load_build({ build_name: BUILD });   // reload: add_item keeps prior sets
  for (const [slot, key] of Object.entries(set)) {
    if (slot === "cost") continue;
    await tools.pob.add_item({ item_text: ITEMS[key], slot_name: slot });
  }
  // gear: which item went in which slot, so the report can list the pick's items only.
  out[label] = {
    cost: set.cost,
    gear: Object.fromEntries(Object.entries(set).filter(([s]) => s !== "cost")),
    ...(await snap()),
  };
}
await tools.pob.lua_load_build({ build_name: BUILD });
return out;`;

// Self-check: the program is written for the code-mode runtime (top-level await,
// top-level return). Wrap it in a function so `node --check` can validate the syntax
// here, rather than discovering a broken program after pasting it.
try {
  const { execFileSync } = await import("node:child_process");
  const { mkdtempSync, writeFileSync } = await import("node:fs");
  const { tmpdir } = await import("node:os");
  const { join } = await import("node:path");
  const check = join(mkdtempSync(join(tmpdir(), "pobsim-")), "check.mjs");
  writeFileSync(check, "async function __run() {\n" + program + "\n}\n");
  execFileSync("node", ["--check", check], { stdio: "pipe" });
  console.error("syntax check: ok");
} catch (e) {
  console.error("SYNTAX CHECK FAILED — do not paste this program:");
  console.error(String(e.stderr || e.message).slice(0, 400));
  process.exit(1);
}

process.stdout.write(program + "\n");
console.error(`sim program ready: ${Object.keys(items).length} items, ${Object.keys(sets).length} sets, build ${build}`);
console.error(`paste it into the code-mode \`execute\` tool, then:`);
console.error(`  node scripts/table.mjs --pick <label> --file /tmp/opencode/sim-out.json`);
