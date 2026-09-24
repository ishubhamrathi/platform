#!/usr/bin/env node
/**
 * Seed AskAI knowledge base via Admin APIs (no Flyway migration).
 * - Logs in via POST /api/auth/login (ADMIN role required)
 * - GET /api/ama/admin/knowledge to dedup by question text (case-insensitive)
 * - POST /api/ama/admin/knowledge for each missing entry
 * - POST /api/admin/ama/suggestions for suggestion chips
 *
 * Usage:
 *   node scripts/seed-ama-knowledge.mjs --api=http://localhost:8080 --email=admin@example.com --password=secret
 *   # or via env: API_BASE, ADMIN_EMAIL, ADMIN_PASSWORD
 *
 * Requires: Node 18+ (global fetch). Data files: scripts/ama-seed-data.json, scripts/ama-suggestions.json
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const API_BASE = process.env.API_BASE || process.argv.find(a=>a.startsWith('--api='))?.split('=')[1] || 'http://localhost:8080';
const EMAIL = process.env.ADMIN_EMAIL || process.argv.find(a=>a.startsWith('--email='))?.split('=')[1] || '';
const PASSWORD = process.env.ADMIN_PASSWORD || process.argv.find(a=>a.startsWith('--password='))?.split('=')[1] || '';

if (!EMAIL || !PASSWORD) {
  console.error('Missing --email and --password (or ADMIN_EMAIL/ADMIN_PASSWORD env).');
  console.error('Tip: if you just registered, run in psql: UPDATE users SET role=\'ADMIN\' WHERE email=\'you@example.com\';');
  process.exit(1);
}

const knowledgePath = path.join(__dirname, 'ama-seed-data.json');
const suggestionsPath = path.join(__dirname, 'ama-suggestions.json');

if (!fs.existsSync(knowledgePath)) {
  console.error(`Missing ${knowledgePath}. Run scripts/generate-knowledge.py first.`);
  process.exit(1);
}
const entries = JSON.parse(fs.readFileSync(knowledgePath, 'utf-8'));
const suggestions = fs.existsSync(suggestionsPath) ? JSON.parse(fs.readFileSync(suggestionsPath, 'utf-8')) : [];

let cookie = '';

async function api(pathname, opts = {}) {
  const url = `${API_BASE}${pathname}`;
  const headers = { 'Content-Type': 'application/json', ...(opts.headers||{}) };
  if (cookie) headers['Cookie'] = cookie;
  const res = await fetch(url, { ...opts, headers, credentials: 'include' });
  const setCookie = res.headers.get('set-cookie');
  if (setCookie) {
    // Keep JSESSIONID / SESSION
    const m = setCookie.match(/SESSION=[^;]+/) || setCookie.match(/JSESSIONID=[^;]+/);
    if (m) cookie = m[0];
  }
  const text = await res.text();
  let json;
  try { json = text ? JSON.parse(text) : null; } catch { json = text; }
  if (!res.ok) {
    const err = json?.error || json?.message || text || res.statusText;
    throw new Error(`${opts.method||'GET'} ${pathname} -> ${res.status} ${err}`);
  }
  return json;
}

console.log(`API: ${API_BASE}  User: ${EMAIL}`);
console.log('Logging in...');
await api('/api/auth/login', { method: 'POST', body: JSON.stringify({ email: EMAIL, password: PASSWORD }) });
console.log('Logged in, cookie:', cookie ? cookie.slice(0, 40)+'...' : '(none)');

console.log('Fetching existing knowledge...');
const existing = await api('/api/ama/admin/knowledge');
const existingSet = new Set((existing||[]).map(e => (e.question||'').trim().toLowerCase()));
console.log(`Existing: ${existing.length} entries. Seed file: ${entries.length}`);

let created = 0, skipped = 0, failed = 0;
for (const e of entries) {
  const key = (e.question||'').trim().toLowerCase();
  if (existingSet.has(key)) { skipped++; continue; }
  try {
    await api('/api/ama/admin/knowledge', {
      method: 'POST',
      body: JSON.stringify({
        category: e.category || 'general',
        question: e.question,
        answer: e.answer,
        keywords: e.keywords || [],
        confidence: e.confidence ?? 0.9,
        active: e.active ?? true,
      }),
    });
    created++;
    existingSet.add(key);
    if (created % 25 === 0) console.log(`  ... ${created} created`);
    // small throttle to avoid rate issues
    await new Promise(r => setTimeout(r, 40));
  } catch (err) {
    failed++;
    console.error(`  FAIL "${e.question.slice(0,60)}": ${err.message}`);
  }
}
console.log(`Knowledge: created=${created} skipped(dup)=${skipped} failed=${failed} total=${entries.length}`);

// Suggestions
if (suggestions.length) {
  console.log('Seeding suggestions...');
  let sCreated = 0, sSkipped = 0;
  // fetch existing suggestions if endpoint available
  let existingSug = [];
  try { const r = await api('/api/admin/ama/suggestions'); existingSug = r.items || r || []; } catch {}
  const sugSet = new Set(existingSug.map(s => (s.question||'').trim().toLowerCase()));
  for (const s of suggestions) {
    const k = (s.question||'').trim().toLowerCase();
    if (sugSet.has(k)) { sSkipped++; continue; }
    try {
      await api('/api/admin/ama/suggestions', {
        method: 'POST',
        body: JSON.stringify({ question: s.question, category: s.category, displayOrder: s.displayOrder, active: true }),
      });
      sCreated++;
    } catch (e) {
      console.error(`  sug FAIL "${s.question}": ${e.message}`);
    }
  }
  console.log(`Suggestions: created=${sCreated} skipped=${sSkipped}`);
}

console.log('Done. Verify: GET /api/ama/admin/knowledge and POST /api/ama/ask with mode KNOWLEDGE_FIRST');
console.log('Test: curl -H "X-API-Key: <portfolio-key>" -H "Content-Type: application/json" -d \'{"question":"more","mode":"KNOWLEDGE_FIRST"}\' $API_BASE/api/ama/ask');
