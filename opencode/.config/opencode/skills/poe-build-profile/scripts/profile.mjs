#!/usr/bin/env node
// Emit a ready-to-paste code-mode program that identifies a build from PoB's own numbers.
// The program returns the finished report as a string: no intermediate file, no
// hand-written statistics, no guessing from mod text.
//
//   node scripts/profile.mjs --build current88.xml > /tmp/opencode/profile.js
//
// Then paste it into the code-mode `execute` tool. The return value IS the answer.
//
// The classifier logic lives in scripts/classify-core.mjs and is inlined below, so the
// pure function stays unit-testable while the emitted program stays one self-contained
// paste.
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));

const argv = process.argv.slice(2);
const args = {};
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a.startsWith("--")) {
    const k = a.slice(2).replace(/-/g, "_");
    args[k] = argv[i + 1] && !argv[i + 1].startsWith("--") ? argv[++i] : true;
  }
}
if (!args.build) {
  console.error("usage: profile.mjs --build <build.xml>");
  console.error("the build must already be saved with lua_save_build({build_name})");
  process.exit(2);
}

const core = readFileSync(join(here, "classify-core.mjs"), "utf8")
  .replace(/^export /gm, "")
  .trim();

const program = `const BUILD = ${JSON.stringify(args.build)};

// analyze_build needs a saved build. It returns PoB's own stat sheet, skill groups and
// equipped items — everything the classifier reads.
const analyze = String(await tools.pob.analyze_build({ build_name: BUILD }));

// The DoT components are the archetype signal; keep them raw so a rename in the summary
// text cannot hide them.
const components = {};
for (const filter of ["Bleed", "Ignite", "Poison", "Dot"]) {
  try {
    const s = String(await tools.pob.export_full_stats({ filter }));
    for (const key of ["BleedDPS", "BleedChance", "IgniteDPS", "PoisonDPS", "TotalDotDPS", "TotalDot"]) {
      const m = s.match(new RegExp('"' + key + '":\\\\s*(-?[\\\\d.]+)'));
      if (m) components[key] = +m[1];
    }
  } catch (e) { /* a filter PoB does not expose is fine */ }
}

${core}

return classify({ build: BUILD, analyze, components });`;

// Self-check before the model ever pastes it: the program uses top-level await/return,
// so validate it inside an async wrapper.
try {
  const check = join(mkdtempSync(join(tmpdir(), "pobprofile-")), "check.mjs");
  writeFileSync(check, "async function __run() {\n" + program + "\n}\n");
  execFileSync("node", ["--check", check], { stdio: "pipe" });
  console.error("syntax check: ok");
} catch (e) {
  console.error("SYNTAX CHECK FAILED — do not paste this program:");
  console.error(String(e.stderr || e.message).slice(0, 600));
  process.exit(1);
}

process.stdout.write(program + "\n");
console.error(`profile program ready for ${args.build}`);
console.error("paste it into code-mode `execute`; the returned string is the report");
