#!/usr/bin/env node
import { createHash } from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const skillRoot = path.resolve(__dirname, "..");
const today = new Date().toISOString().slice(0, 10);

const args = parseArgs(process.argv.slice(2));
const catalogPath = path.resolve(skillRoot, args.catalog ?? "assets/catalog.csv");
const seedPath = path.resolve(skillRoot, args.seeds ?? "assets/sources/seed_sources.csv");
const queriesPath = path.resolve(skillRoot, args.queries ?? "assets/sources/github_queries.txt");
const formatsDir = path.resolve(skillRoot, args.outDir ?? "assets/formats/github");
const maxPerQuery = Number(args.maxPerQuery ?? args["max-per-query"] ?? 5);
const metadataOnly = Boolean(args.metadataOnly ?? args["metadata-only"] ?? args.noDownload ?? args["no-download"]);
const seedOnly = Boolean(args.seedOnly ?? args["seed-only"]);
const searchOnly = Boolean(args.searchOnly ?? args["search-only"]);

const token = process.env.GITHUB_TOKEN || "";

main().catch((error) => {
  console.error(error?.stack || String(error));
  process.exit(1);
});

async function main() {
  await fs.mkdir(formatsDir, { recursive: true });

  const existing = await readCatalog(catalogPath);
  const byId = new Map(existing.map((row) => [row.id, row]));
  const bySource = new Map(existing.map((row) => [normalizeUrl(row.source_url), row]));

  const discovered = [];

  if (!searchOnly) {
    const seeds = await readCsvIfExists(seedPath);
    for (const seed of seeds) {
      if (!seed.source_url) continue;
      discovered.push(await rowFromSource(seed));
    }
  }

  if (!seedOnly) {
    const queries = await readLinesIfExists(queriesPath);
    for (const query of queries) {
      const repos = await searchGitHub(query, maxPerQuery);
      for (const repo of repos) {
        discovered.push(rowFromRepo(repo));
      }
    }
  }

  const unique = dedupeRows(discovered);
  let downloaded = 0;
  let metadata = 0;
  let failed = 0;

  for (const incoming of unique) {
    const old = byId.get(incoming.id) || bySource.get(normalizeUrl(incoming.source_url)) || {};
    const merged = mergeRows(old, incoming);

    if (metadataOnly) {
      merged.status = merged.status === "downloaded" ? "downloaded" : "metadata-only";
      metadata += 1;
    } else {
      try {
        const result = await downloadRow(merged);
        merged.local_path = result.localPath;
        merged.sha256 = result.sha256;
        merged.status = "downloaded";
        downloaded += 1;
      } catch (error) {
        merged.status = old.status || "failed";
        merged.notes = appendNote(merged.notes, `download failed: ${error.message}`);
        failed += 1;
      }
    }

    merged.last_checked = today;
    byId.set(merged.id, merged);
    bySource.set(normalizeUrl(merged.source_url), merged);
  }

  const rows = [...byId.values()].sort((a, b) => a.id.localeCompare(b.id));
  await writeCatalog(catalogPath, rows);

  console.log(`catalog: ${catalogPath}`);
  console.log(`rows: ${rows.length}`);
  console.log(`new/checked: ${unique.length}`);
  console.log(`downloaded: ${downloaded}`);
  console.log(`metadata-only: ${metadata}`);
  console.log(`failed: ${failed}`);
}

function parseArgs(argv) {
  const result = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!arg.startsWith("--")) continue;
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

async function rowFromSource(seed) {
  const slug = parseGitHubSlug(seed.source_url);
  if (seed.source_kind === "github" && slug) {
    try {
      const repo = await getRepo(slug);
      return mergeRows(seed, rowFromRepo(repo, seed));
    } catch {
      return normalizeSeed(seed);
    }
  }
  return normalizeSeed(seed);
}

function normalizeSeed(seed) {
  const sourceUrl = seed.source_url || "";
  const slug = parseGitHubSlug(sourceUrl);
  const id = seed.id || (slug ? `github_${slug.replace("/", "_")}` : stableId(sourceUrl));
  return {
    id,
    university: seed.university || "",
    aliases: seed.aliases || "",
    level: seed.level || "unknown",
    template_type: seed.template_type || "unknown",
    format: seed.format || "unknown",
    source_kind: seed.source_kind || inferSourceKind(sourceUrl),
    source_url: sourceUrl,
    download_url: seed.download_url || "",
    local_path: "",
    sha256: "",
    license: seed.license || "unknown",
    last_checked: today,
    status: "metadata-only",
    notes: seed.notes || "",
  };
}

async function searchGitHub(query, perPage) {
  const url = new URL("https://api.github.com/search/repositories");
  url.searchParams.set("q", query);
  url.searchParams.set("sort", "stars");
  url.searchParams.set("order", "desc");
  url.searchParams.set("per_page", String(Math.min(Math.max(perPage, 1), 100)));
  const json = await fetchJson(url);
  return json.items || [];
}

async function getRepo(slug) {
  return fetchJson(`https://api.github.com/repos/${slug}`);
}

function rowFromRepo(repo, seed = {}) {
  const slug = repo.full_name || parseGitHubSlug(seed.source_url);
  const inferred = inferUniversity(repo);
  const defaultBranch = seed.download_url?.split("/").pop() || repo.default_branch || "main";
  const description = cleanText(repo.description || "");
  const topics = Array.isArray(repo.topics) ? repo.topics.join("|") : "";
  const license = seed.license || repo.license?.spdx_id || repo.license?.name || "unknown";

  return {
    id: seed.id || `github_${slug.replace("/", "_")}`,
    university: seed.university || inferred.university,
    aliases: seed.aliases || inferred.aliases,
    level: seed.level || inferLevel(`${repo.name} ${description} ${topics}`),
    template_type: seed.template_type || inferTemplateType(`${repo.name} ${description}`),
    format: seed.format || inferFormat(`${repo.language || ""} ${repo.name} ${description} ${topics}`),
    source_kind: "github",
    source_url: seed.source_url || repo.html_url || `https://github.com/${slug}`,
    download_url: seed.download_url || `https://api.github.com/repos/${slug}/zipball/${defaultBranch}`,
    local_path: "",
    sha256: "",
    license,
    last_checked: today,
    status: "metadata-only",
    notes: appendNote(seed.notes || "", `GitHub stars=${repo.stargazers_count ?? "unknown"}; ${description}`),
  };
}

async function downloadRow(row) {
  if (!row.download_url) {
    throw new Error("missing download_url");
  }

  const url = row.download_url;
  const sourceSlug = parseGitHubSlug(row.source_url);
  const branch = safeSegment(url.split("/").pop() || "archive");
  const base = sourceSlug ? sourceSlug.replace("/", "__") : safeSegment(row.id);
  const targetDir = path.resolve(formatsDir, base);
  const targetPath = path.resolve(targetDir, `${base}__${branch}.zip`);
  await fs.mkdir(targetDir, { recursive: true });

  const data = await fetchBinary(url);
  await fs.writeFile(targetPath, data);
  const sha256 = createHash("sha256").update(data).digest("hex");
  return {
    localPath: normalizePath(path.relative(skillRoot, targetPath)),
    sha256,
  };
}

async function fetchJson(url) {
  const res = await fetch(url, {
    headers: githubHeaders(),
  });
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`GitHub request failed ${res.status}: ${body.slice(0, 240)}`);
  }
  return res.json();
}

async function fetchBinary(url) {
  const res = await fetch(url, {
    headers: githubHeaders(),
    redirect: "follow",
  });
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`download failed ${res.status}: ${body.slice(0, 240)}`);
  }
  return Buffer.from(await res.arrayBuffer());
}

function githubHeaders() {
  const headers = {
    "Accept": "application/vnd.github+json",
    "User-Agent": "cn-thesis-template-collection",
    "X-GitHub-Api-Version": "2022-11-28",
  };
  if (token) headers.Authorization = `Bearer ${token}`;
  return headers;
}

function dedupeRows(rows) {
  const seen = new Map();
  for (const row of rows.filter(Boolean)) {
    const key = row.id || normalizeUrl(row.source_url);
    if (!key) continue;
    seen.set(key, mergeRows(seen.get(key) || {}, row));
  }
  return [...seen.values()];
}

function mergeRows(oldRow, newRow) {
  const merged = {};
  for (const key of catalogFields) {
    if (key === "status" && oldRow[key] === "downloaded" && newRow[key] === "metadata-only") {
      merged[key] = oldRow[key];
    } else {
      merged[key] = newRow[key] || oldRow[key] || "";
    }
  }
  merged.notes = appendNote(oldRow.notes || "", newRow.notes || "");
  if (!merged.status) merged.status = "metadata-only";
  if (!merged.last_checked) merged.last_checked = today;
  return merged;
}

function appendNote(left, right) {
  const parts = [];
  for (const value of [left, right]) {
    for (const segment of String(value || "").split(/\s+\|\s+/)) {
      const text = cleanText(segment || "");
      if (text && !parts.includes(text)) parts.push(text);
    }
  }
  return parts.join(" | ");
}

function inferUniversity(repo) {
  const text = `${repo.full_name || ""} ${repo.name || ""} ${repo.description || ""} ${(repo.topics || []).join(" ")}`.toLowerCase();
  const patterns = [
    [/xjtu|西安交通大学|xi'?an jiaotong/i, "西安交通大学", "XJTU|Xi'an Jiaotong University"],
    [/sjtu|上海交通大学|shanghai jiao tong/i, "上海交通大学", "SJTU|Shanghai Jiao Tong University"],
    [/tsinghua|清华|thu[-_]?thesis/i, "清华大学", "THU|Tsinghua University"],
    [/pku|北京大学|peking university/i, "北京大学", "PKU|Peking University"],
    [/ustc|中国科学技术大学/i, "中国科学技术大学", "USTC|University of Science and Technology of China"],
    [/zju|浙江大学|zhejiang university/i, "浙江大学", "ZJU|Zhejiang University"],
    [/nju|南京大学|nanjing university/i, "南京大学", "NJU|Nanjing University"],
    [/fudan|复旦/i, "复旦大学", "FDU|Fudan University"],
    [/buaa|北航|北京航空航天/i, "北京航空航天大学", "BUAA|Beihang University"],
    [/bit|北京理工/i, "北京理工大学", "BIT|Beijing Institute of Technology"],
    [/hust|华中科技/i, "华中科技大学", "HUST|Huazhong University of Science and Technology"],
    [/xdu|西安电子科技/i, "西安电子科技大学", "XDU|Xidian University"],
    [/njust|南京理工/i, "南京理工大学", "NJUST|Nanjing University of Science and Technology"],
    [/scut|华南理工/i, "华南理工大学", "SCUT|South China University of Technology"],
    [/uestc|电子科技大学/i, "电子科技大学", "UESTC|University of Electronic Science and Technology of China"],
    [/ncepu|华北电力/i, "华北电力大学", "NCEPU|North China Electric Power University"],
    [/tju|天津大学|tianjin university/i, "天津大学", "TJU|Tianjin University"],
    [/hit|哈工大|哈尔滨工业大学|hithesis/i, "哈尔滨工业大学", "HIT|Harbin Institute of Technology"],
    [/ucas|中国科学院大学|university of chinese academy/i, "中国科学院大学", "UCAS|University of Chinese Academy of Sciences"],
    [/cqu|重庆大学|chongqing university/i, "重庆大学", "CQU|Chongqing University"],
    [/scu[-_]?thesis|四川大学|sichuan university/i, "四川大学", "SCU|Sichuan University"],
    [/sysu|中山大学|sun yat-sen/i, "中山大学", "SYSU|Sun Yat-sen University"],
    [/tongji|同济大学/i, "同济大学", "Tongji University"],
    [/ynu|云南大学|yunnan university/i, "云南大学", "YNU|Yunnan University"],
  ];
  for (const [pattern, university, aliases] of patterns) {
    if (pattern.test(text)) return { university, aliases };
  }
  return { university: "", aliases: "" };
}

function inferLevel(text) {
  const value = text.toLowerCase();
  const undergrad = /本科|学士|bachelor|undergraduate/.test(value);
  const grad = /研究生|硕士|博士|master|doctor|graduate|dissertation/.test(value);
  if (undergrad && grad) return "multiple";
  if (undergrad) return "undergraduate";
  if (grad) return "graduate";
  return "unknown";
}

function inferTemplateType(text) {
  const value = text.toLowerCase();
  if (/proposal|开题/.test(value)) return "proposal";
  if (/defense|答辩|beamer/.test(value)) return "defense";
  if (/format|规范|要求/.test(value)) return "format-requirement";
  if (/dissertation|学位论文|博士|硕士/.test(value)) return "dissertation";
  if (/thesis|毕业论文|毕业设计/.test(value)) return "thesis";
  return "unknown";
}

function inferFormat(text) {
  const value = text.toLowerCase();
  const latex = /latex|tex|ctex|cls|bibtex/.test(value);
  const word = /word|docx|office/.test(value);
  const pdf = /pdf/.test(value);
  const formats = [];
  if (latex) formats.push("latex");
  if (word) formats.push("word");
  if (pdf) formats.push("pdf");
  if (formats.length > 1) return "multiple";
  return formats[0] || "unknown";
}

function inferSourceKind(sourceUrl) {
  if (/github\.com/i.test(sourceUrl)) return "github";
  if (/ctan\.org|mirrors\..*ctan/i.test(sourceUrl)) return "ctan";
  if (/overleaf\.com/i.test(sourceUrl)) return "overleaf";
  if (/\.edu\.cn/i.test(sourceUrl)) return "official";
  return "other-public";
}

function parseGitHubSlug(url) {
  const match = String(url || "").match(/github\.com[/:]([^/\s]+)\/([^/\s?#.]+)(?:\.git)?/i);
  if (!match) return "";
  return `${match[1]}/${match[2].replace(/\.git$/i, "")}`;
}

function stableId(value) {
  const hash = createHash("sha1").update(String(value)).digest("hex").slice(0, 12);
  return `source_${hash}`;
}

function safeSegment(value) {
  return String(value || "unknown").replace(/[^\w.-]+/g, "_").replace(/^_+|_+$/g, "") || "unknown";
}

function normalizePath(value) {
  return value.split(path.sep).join("/");
}

function normalizeUrl(value) {
  return String(value || "").trim().replace(/\/+$/, "");
}

function cleanText(value) {
  return String(value || "").replace(/\s+/g, " ").trim();
}

async function readLinesIfExists(filePath) {
  try {
    const text = await fs.readFile(filePath, "utf8");
    return text.split(/\r?\n/).map((line) => line.trim()).filter((line) => line && !line.startsWith("#"));
  } catch (error) {
    if (error.code === "ENOENT") return [];
    throw error;
  }
}

async function readCsvIfExists(filePath) {
  try {
    const text = await fs.readFile(filePath, "utf8");
    return parseCsv(text);
  } catch (error) {
    if (error.code === "ENOENT") return [];
    throw error;
  }
}

async function readCatalog(filePath) {
  try {
    const rows = parseCsv(await fs.readFile(filePath, "utf8"));
    return rows.map((row) => {
      const normalized = {};
      for (const field of catalogFields) normalized[field] = row[field] || "";
      return normalized;
    });
  } catch (error) {
    if (error.code === "ENOENT") return [];
    throw error;
  }
}

async function writeCatalog(filePath, rows) {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  const lines = [catalogFields.join(",")];
  for (const row of rows) {
    lines.push(catalogFields.map((field) => csvCell(row[field] || "")).join(","));
  }
  await fs.writeFile(filePath, `${lines.join("\n")}\n`, "utf8");
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

function csvCell(value) {
  const text = String(value ?? "");
  if (/[",\n\r]/.test(text)) return `"${text.replace(/"/g, '""')}"`;
  return text;
}

const catalogFields = [
  "id",
  "university",
  "aliases",
  "level",
  "template_type",
  "format",
  "source_kind",
  "source_url",
  "download_url",
  "local_path",
  "sha256",
  "license",
  "last_checked",
  "status",
  "notes",
];
