#!/usr/bin/env node
// Contract lint for the skill.
//
// The skill is a contract: SKILL.md and reference/ may only change when a rule
// changes. Run data (prices, seller handles, dates, "this session") silently rots
// those files and makes every run look like it needs another edit, so it is
// rejected here instead. Evidence belongs in findings.md.
//
//   node scripts/check.mjs          # exit 1 on any violation
//
// Wired into the repo's pre-commit hook.

import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const problems = [];
const warn = [];

const read = (rel) => readFileSync(join(root, rel), "utf8");
const list = (rel, ext) =>
  readdirSync(join(root, rel))
    .filter((f) => f.endsWith(ext))
    .sort()
    .map((f) => `${rel}/${f}`);

// findings.md is the notebook: numbers, dates and sellers are its whole point.
// This file is the checker; it necessarily names the patterns it rejects.
const contract = [
  "SKILL.md",
  ...list("reference", ".md"),
  ...list("scripts", ".mjs").filter((f) => !f.endsWith("/check.mjs")),
];

const rules = [
  {
    re: /\b\d+\s?(?:c|chaos|divine)\b/g,
    why: "price — findings.md records prices, the contract states the filter",
  },
  {
    re: /#\d{4}\b/g,
    why: "account handle — findings.md",
    allow: ["#0000"],
  },
  {
    re: /\b\d{4}-\d{2}-\d{2}\b|\b\d{1,2}\/\d{1,2}\/\d{2,4}\b/g,
    why: "date — findings.md",
  },
  {
    re: /\bthis session\b/gi,
    why: '"this session" — a rule has to stand without the session',
  },
];

for (const rel of contract) {
  const text = read(rel);
  const lines = text.split("\n");
  for (const { re, why, allow = [] } of rules) {
    re.lastIndex = 0;
    for (const m of text.matchAll(re)) {
      if (allow.some((a) => m[0].includes(a))) continue;
      const line = text.slice(0, m.index).split("\n").length;
      problems.push(`${rel}:${line}  "${m[0].trim()}"  — ${why}`);
    }
  }
  if (!lines.length) problems.push(`${rel}: empty`);
}

// A spec pins a filter set. min === max is one listing's rolls, not a filter set:
// it is a run artifact and must not accumulate in the repo.
for (const rel of list("specs", ".json")) {
  let spec;
  try {
    spec = JSON.parse(read(rel));
  } catch (e) {
    problems.push(`${rel}: invalid JSON (${e.message})`);
    continue;
  }
  for (const group of spec.stats || []) {
    for (const s of group.filters || []) {
      const v = s.value || {};
      if (v.min !== undefined && v.min === v.max) {
        problems.push(
          `${rel}: pins ${s.id} to exactly ${v.min} — one listing, not a filter set; ` +
            `keep it in /tmp/opencode`
        );
      }
    }
  }
}

// Soft signal: a spec nobody documents is probably a leftover run artifact.
const readme = read("scripts/README.md");
for (const rel of list("specs", ".json")) {
  const name = rel.slice("specs/".length);
  if (!readme.includes(name)) warn.push(`${rel}: not listed in scripts/README.md`);
}

if (problems.length) {
  console.error("skill contract check FAILED\n");
  for (const p of problems) console.error("  " + p);
  console.error(
    "\nRules belong in SKILL.md/reference; evidence belongs in findings.md."
  );
  process.exit(1);
}

for (const w of warn) console.error("warn: " + w);
console.log(`skill contract clean (${contract.length} files)`);
