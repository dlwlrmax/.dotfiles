// Pure classifier: takes the analyze_build dump and returns the report string.
// No filesystem, no PoB access — profile.mjs inlines this into the emitted program,
// so the whole profile is one code-mode paste with no intermediate file.

export function classify(dump) {
  const text = String(dump.analyze || "");
  if (!text.includes("=== Stats ===")) {
    return "profile has no analyze_build dump — check that the build was saved with lua_save_build";
  }

  const section = (name) => {
    const m = text.match(new RegExp("=== " + name + " ===\\n([\\s\\S]*?)(?=\\n=== |$)"));
    return m ? m[1] : "";
  };
  const meta = {};
  for (const m of text.matchAll(/^(Class|Ascendancy|Level): (.+)$/gm)) meta[m[1]] = m[2].trim();

  const stats = {};
  for (const m of section("Stats").matchAll(/^([A-Za-z:]+): (-?[\d.]+)$/gm)) stats[m[1]] = +m[2];

  const groups = section("Skills")
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l.includes("("))
    .map((l) => l.split(" - ").map((g) => {
      const m = g.match(/^(.*?) \((\d+)\/(\d+)\)$/);
      return m ? { name: m[1], level: +m[2], quality: +m[3] } : { name: g.trim(), level: 0, quality: 0 };
    }));

  const items = [];
  for (const m of section("Items").matchAll(/^(.+?): \[(\w+)\] (.+?) \((.+?)\)$/gm)) {
    items.push({ slot: m[1], rarity: m[2], name: m[3], base: m[4] });
  }

  const s = { ...stats, ...(dump.components || {}) };
  const num = (k) => (typeof s[k] === "number" ? s[k] : null);
  const combined = num("CombinedDPS") || 0;
  const bleed = num("BleedDPS") || 0;
  const ignite = num("IgniteDPS") || 0;
  const poison = num("PoisonDPS") || 0;
  const dot = num("TotalDotDPS") || 0;
  const crit = num("CritChance") || 0;
  const hit = num("HitChance");

  let archetype = "hit";
  if (poison > 0 && poison >= bleed && poison >= ignite) archetype = "poison";
  else if (ignite > 0 && ignite >= bleed) archetype = "ignite";
  else if (bleed > 0) archetype = "bleed";

  const dotShare = combined > 0 ? (dot / combined) * 100 : 0;
  const mainGroup = groups[0] || [];
  const mainSkill = mainGroup.find((g) => g.level > 0) || { name: "?", level: 0, quality: 0 };
  const supports = mainGroup.slice(1).map((g) => g.name);
  const allSkills = new Set(groups.flat().map((g) => g.name));
  const belt = items.find((i) => i.slot === "Belt");
  const hasBelt = (n) => !!belt && new RegExp(n, "i").test(belt.name);

  const ARCHETYPES = {
    bleed: {
      metric: "BleedDPS + AverageDamage (damage per hit). Never pDPS, never attack speed.",
      levers: ["damage per hit", "+% Damage over Time Multiplier", "flat physical damage",
        "aggravate / forced-move uptime", "gem levels and quality"],
      required: ["Fist of War", "Brutality", "Melee Physical Damage"],
      wants: [["Vulnerability", "curse: increased physical damage taken + aggravate on quality"]],
    },
    ignite: {
      metric: "IgniteDPS. Fire damage per hit sets the ignite; attack/cast speed does not.",
      levers: ["fire damage per hit", "+% Fire Damage over Time Multiplier", "exposure",
        "ignite duration", "gem levels"],
      required: ["Combustion", "Immolate"],
      wants: [["Flammability", "curse: fire resistance reduction"]],
    },
    poison: {
      metric: "PoisonDPS. Stacks multiply, so hit rate matters as much as hit size.",
      levers: ["chaos damage per hit", "+% Chaos Damage over Time Multiplier", "poison stacks",
        "wither", "gem levels"],
      required: ["Deadly Ailments", "Void Manipulation"],
      wants: [["Despair", "curse: chaos resistance reduction"]],
    },
    hit: {
      metric: "CombinedDPS with HitChance at 100. Average hit x rate; ailment stats are noise.",
      levers: ["added damage", "% increased damage", "crit chance and multi (only if crit > 0)",
        "attack/cast speed", "gem levels"],
      required: [],
      wants: [],
    },
  };
  const rule = ARCHETYPES[archetype];

  const flags = [];
  const notes = [];
  const add = (level, msg) => flags.push({ level, msg });

  const unreserved = num("ManaUnreserved");
  if (unreserved !== null && unreserved < 0) {
    add("critical", `unreserved mana ${unreserved} — the reservation cannot run in game, ` +
      `so PoB's DPS includes auras you cannot sustain. Fix reservation before buying damage.`);
  }
  const life = num("Life");
  if (life !== null && life < 4500) add("warn", `life ${life} — under the 4.5k floor for T16 mapping`);
  if ((num("ChaosResist") ?? 0) < 0) add("warn", `chaos resist ${num("ChaosResist")} — negative chaos is a one-shot risk`);
  for (const el of ["Fire", "Cold", "Lightning"]) {
    const oc = num(`${el}ResistOverCap`);
    if (oc !== null && oc < 20) add("warn", `${el.toLowerCase()} overcap +${oc} — under the +20 target (curses reach −30)`);
  }
  if (hit !== null && hit < 100) add("warn", `hit chance ${hit}% — accuracy is costing damage`);

  if (crit === 0) {
    notes.push("crit chance is 0 (Resolute Technique or no investment): crit chance/multi gear is dead weight");
  }
  for (const [needle, why] of rule.wants) {
    if (!allSkills.has(needle)) add("warn", `no ${needle} in any socket group — ${why}`);
  }
  const missingSupports = rule.required.filter((r) => !supports.some((sp) => sp.startsWith(r)));
  if (missingSupports.length) {
    add("warn", `main link is missing archetype supports: ${missingSupports.join(", ")}`);
  }

  if (archetype === "bleed") {
    if (supports.some((x) => x.startsWith("Swift Affliction"))) {
      notes.push("Swift Affliction cuts bleed duration by 25%: more DoT DPS, shorter window — " +
        "re-simulate it against the incumbent support instead of assuming it wins");
    }
    if (supports.some((x) => x.startsWith("Volatility")) && hasBelt("Ryslatha")) {
      add("warn", "Volatility + Ryslatha's Coil: low-roll hits can leave a mob almost unhurt while mapping");
    }
    if (hasBelt("Ryslatha")) notes.push("Ryslatha's Coil is a damage belt: quality it with Abrasive Catalysts");
  }

  const under20 = groups.flat().filter((g) => g.level > 0 && g.level < 20);
  const mainUnder20 = mainGroup.filter((g) => g.level > 0 && g.level < 20);
  const otherUnder20 = under20.length - mainUnder20.length;
  if (mainUnder20.length) {
    notes.push(`main link below level 20: ${mainUnder20.map((g) => `${g.name} ${g.level}/${g.quality}`).join(", ")} — leveling is free`);
  }
  if (otherUnder20 > 0) notes.push(`${otherUnder20} other gem(s) below level 20 — level the ones that are actually in use`);
  const poorQuality = mainGroup.filter((g) => g.level >= 20 && g.quality < 20);
  if (poorQuality.length) {
    notes.push(`${poorQuality.length} main-link gem(s) at 20 with quality below 20 — Gemcutter's Prism is the cheap part`);
  }

  const headroom = ["Str", "Dex", "Int"].map((k) => {
    const own = num(k), req = num("Req" + k);
    return own === null || req === null ? null : `${k} ${own} (req ${req}, +${own - req})`;
  }).filter(Boolean);

  const out = [];
  out.push(`# Build profile — ${meta.Class || "?"} / ${meta.Ascendancy || "?"} ${meta.Level || "?"}`, "");
  out.push(`main skill   ${mainSkill.name} (${mainSkill.level}/${mainSkill.quality})`);
  out.push(`supports     ${supports.join(", ") || "none"}`);
  out.push(`archetype    ${archetype.toUpperCase()}${dot > 0 ? ` — DoT is ${dotShare.toFixed(0)}% of CombinedDPS` : ""}`);
  out.push(`metric       ${rule.metric}`, "");
  out.push("## Scales with", "");
  for (const l of rule.levers) out.push(`- ${l}`);
  if (flags.length) {
    out.push("", "## Fix before buying damage", "");
    for (const f of flags) out.push(`${f.level === "critical" ? "!!" : "! "}${f.msg}`);
  }
  if (notes.length) {
    out.push("", "## Free / cheap levers", "");
    for (const n of notes) out.push(`- ${n}`);
  }
  if (headroom.length) out.push("", "## Attribute headroom", "", headroom.join(" · "));
  out.push("", `_${combined ? `CombinedDPS ${Math.round(combined)} · BleedDPS ${Math.round(bleed)} · ` : ""}` +
    `life ${life ?? "?"} · EHP ${num("TotalEHP") ? Math.round(num("TotalEHP")) : "?"}_`);
  return out.join("\n");
}
