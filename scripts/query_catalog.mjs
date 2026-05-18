#!/usr/bin/env node
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const skillRoot = path.resolve(__dirname, "..");
const args = parseArgs(process.argv.slice(2));
const terms = args._.map((value) => value.toLowerCase());
const catalogPath = path.resolve(skillRoot, args.catalog ?? "assets/catalog.csv");

main().catch((error) => {
  console.error(error?.stack || String(error));
  process.exit(1);
});

async function main() {
  const rows = parseCsv(await fs.readFile(catalogPath, "utf8"));
  const matched = rows.filter(matches);

  if (!matched.length) {
    console.log("No catalog rows matched.");
    process.exit(2);
  }

  for (const row of matched.slice(0, Number(args.limit || 50))) {
    console.log([
      row.university || "(unknown university)",
      row.level || "unknown",
      row.format || "unknown",
      row.source_kind || "unknown",
      row.status || "unknown",
    ].join(" | "));
    console.log(`  id: ${row.id}`);
    console.log(`  source: ${row.source_url}`);
    if (row.local_path) console.log(`  local: ${path.resolve(skillRoot, row.local_path)}`);
    if (row.sha256) console.log(`  sha256: ${row.sha256}`);
    if (row.notes) console.log(`  notes: ${row.notes}`);
  }

  if (matched.length > Number(args.limit || 50)) {
    console.log(`... ${matched.length - Number(args.limit || 50)} more rows`);
  }
}

function matches(row) {
  if (args.level && row.level !== args.level) return false;
  if (args.format && row.format !== args.format && row.format !== "multiple") return false;
  if (args.sourceKind && row.source_kind !== args.sourceKind) return false;
  if (args["source-kind"] && row.source_kind !== args["source-kind"]) return false;
  if (args.status && row.status !== args.status) return false;
  if (!terms.length) return true;

  const haystack = [
    row.id,
    row.university,
    row.aliases,
    row.level,
    row.template_type,
    row.format,
    row.source_kind,
    row.source_url,
    row.local_path,
    row.license,
    row.notes,
  ].join(" ").toLowerCase();

  return terms.every((term) => haystack.includes(term));
}

function parseArgs(argv) {
  const result = { _: [] };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!arg.startsWith("--")) {
      result._.push(arg);
      continue;
    }
    const key = arg.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith("--")) {
      result[key] = true;
    } else {
      result[key] = next;
      i += 1;
    }
  }
  return result;
}

function parseCsv(text) {
  const lines = text.replace(/^\uFEFF/, "").split(/\r?\n/).filter((line) => line.trim());
  if (!lines.length) return [];
  const headers = parseCsvLine(lines[0]);
  return lines.slice(1).map((line) => {
    const values = parseCsvLine(line);
    const row = {};
    headers.forEach((header, index) => {
      row[header] = values[index] || "";
    });
    return row;
  });
}

function parseCsvLine(line) {
  const cells = [];
  let cell = "";
  let quoted = false;
  for (let i = 0; i < line.length; i += 1) {
    const char = line[i];
    const next = line[i + 1];
    if (char === '"' && quoted && next === '"') {
      cell += '"';
      i += 1;
    } else if (char === '"') {
      quoted = !quoted;
    } else if (char === "," && !quoted) {
      cells.push(cell);
      cell = "";
    } else {
      cell += char;
    }
  }
  cells.push(cell);
  return cells;
}

