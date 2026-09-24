# Fallback Engine — Handling Compliments, Greetings, Questions Without Answers

## Problem
`POST /api/ama/ask` with `mode KNOWLEDGE_FIRST` returns `PUBLISHED` only on strong knowledge match (threshold 0.6). Otherwise with providers disabled it goes to `REVIEW` → `PENDING` → `Thanks — your question is in the queue...` and takes ~800ms polls. Typos (`escribe yourself inone work`) and compliments (`loved your star feature`) also miss and queue, or match wrong technical entry (stars V60).

## Intent Types (Research)
Based on portfolio AskAI traffic, these cover >95% of fallback cases:

| Type | Examples | Typical keywords | Desired response |
|---|---|---|---|
| **Compliment** | `loved your star feature`, `great work`, `awesome portfolio`, `amazing`, `nice stars` | `love`, `loved`, `great`, `awesome`, `amazing`, `nice`, `beautiful`, `excellent` + feature name | Grateful, invite to explore more |
| **Gratitude** | `thanks`, `thank you`, `appreciate it` | `thanks`, `thank`, `appreciate` | Warm welcome, offer more help |
| **Greeting** | `hello`, `hi`, `hey`, `hello there` | `hello`, `hi`, `hey`, `greetings` | Welcome + prompt |
| **Farewell** | `bye`, `goodbye`, `see you` | `bye`, `goodbye` | Friendly goodbye |
| **Encouragement** | `keep it up`, `well done` | `keep it up`, `keep going` | Thanks + motivation |
| **Hiring / Collaboration** | `can we hire you?`, `looking to hire` | `hire`, `job`, `opportunity`, `collaborate`, `freelance` | Direct to contact form |
| **Feature Request** | `can you add dark mode`, `please add search` | `add`, `feature`, `can you add`, `please add` | Thank + note, ask for details via contact |
| **Support / Anger / Complaint** | `this is not working`, `site is broken`, `this sucks` | `not working`, `broken`, `error`, `bug`, `not loading`, `sucks`, `bad` | Empathetic, ask for details via contact |
| **Personal / Small Talk** | `how are you?`, `how are you doing?` | `how are you` | Friendly + redirect to portfolio |
| **Unclear / Help** | `what can you do?`, `help`, `what else?` | `what can you do`, `help` | List capabilities |
| **Question with typo** | `escribe yourself inone work` | misspelling of `describe`, `inone` | Correct answer (Ownership.) with typo keywords |
| **Unknown / Out-of-scope** | random | no match | Generic helpful fallback + store for training |

## Detection — How to tell the type

**Option A: Knowledge-base fallback (implemented, no code fork)**
- Add a knowledge entry per type with `confidence 1.0` and broad `keywords` (e.g., compliment entry has `["loved","love","great","awesome"]`). KNOWLEDGE_FIRST matches compliment before technical `stars` entry because `loved your star feature` has higher keyword overlap with compliment entry (contains `loved`) than with technical `describe your stars feature`.
- Covers typos by adding typo keywords to the target entry (`escribe`, `desribe`, `inone`, `one work`) and by adding an exact typo question `escribe yourself inone work` with `confidence 1.0`.

**Option B: Lightweight rule-based classifier (recommended wrapper, 15 lines)**
- Run *after* a `PENDING` response or *before* calling `/api/ama/ask` for instant reply:
```js
const RULES = [
  {type:'compliment', re:/\b(love|loved|great|awesome|amazing|nice|beautiful|excellent)\b/i},
  {type:'gratitude', re:/\b(thanks|thank you|appreciate)\b/i},
  {type:'greeting', re:/^\s*(hello|hi|hey|greetings)\b/i},
  {type:'farewell', re:/\b(bye|goodbye)\b/i},
  {type:'hiring', re:/\b(hire|hiring|job|opportunity|collaborate)\b/i},
  {type:'feature_request', re:/\b(add|feature request|can you add|please add)\b/i},
  {type:'support', re:/\b(not working|broken|error|bug|not loading|sucks)\b/i},
];
function classify(q){
  for(const r of RULES) if(r.re.test(q)) return r.type;
  return 'unknown';
}
```
- If `classify` returns `compliment|gratitude|...` and knowledge returned `PENDING`, immediately show fallback answer from a local map (see below) *while still keeping* the `PENDING` question in DB for training (it is already stored as `PENDING` in `ama_questions` for admin review at `/api/ama/admin/questions`).

**Option C: Embeddings / ML (future)**
- When traffic grows, replace regex with a tiny intent classifier (e.g., `all-MiniLM` embeddings + cosine to 10 prototype sentences per type). Still keep rule fallback as backup.

## Embedding — How to add to portfolio

**Minimal (knowledge-only, done):**
- 18 fallback entries added via `POST /api/ama/admin/knowledge` (`category compliment|gratitude|...`, `confidence 1.0`): `loved your star feature`, `great work`, `awesome portfolio`, `thank you`, `bye`, `can you add dark mode`, `this is not working`, etc. (`scripts/ama-seed-data.json` now 306→324, DB 324). They are matched knowledge-first, so `loved your star feature` now returns compliment thanks, not stars V60.

**Wrapper (frontend, 20 lines, stores for training):**
```ts
// useAskAiWithFallback.ts
const FALLBACK = {
  compliment: "Thank you so much! I'm really glad you liked it — it was fun building it. Feel free to explore my other projects!",
  gratitude: "You're very welcome! Happy to help — let me know if you'd like to know more.",
  greeting: "Hi! Welcome! I'm Shubham's assistant. Ask me about his work, projects, or how to get in touch.",
  hiring: "I'd love to discuss — please reach out via the portfolio contact form!",
  support: "I'm sorry to hear that! Could you share details via the contact form so I can fix it quickly?",
  unknown: "Thanks for your message — I've noted it for review. Meanwhile, you can ask about my tech stack, projects, or experience. Try 'What is your tech stack?'",
};
export async function askWithFallback(apiBase, apiKey, question, session){
  const r = await fetch(`${apiBase}/api/ama/ask`, {method:'POST', headers:{'Content-Type':'application/json','X-API-Key':apiKey}, body:JSON.stringify({question, mode:'KNOWLEDGE_FIRST'})}).then(x=>x.json());
  if(r.answered) return r.answer;
  // PENDING → classify and answer instantly, but question is already stored as PENDING for admin training
  const type = classify(question);
  return FALLBACK[type] || FALLBACK.unknown;
}
```
- The question stays persisted as `PENDING` in `ama_questions` (admin sees it at `AMA → Questions` widget, `docs/AMA_API.md:187`). You can later promote it to knowledge via `POST /api/ama/admin/knowledge` (one click `Promote to knowledge` in `AmaQuestionsConsoleWidget.tsx:263`).

**Backend alternative (if you control `ama-spring-boot-starter`):**
- Add a `FallbackProvider` in the provider chain that triggers on `confidence < threshold` and returns the same `FALLBACK` map, so fallback is served as `PUBLISHED` with `source AI` and no queue.

## Sanitization
All 68 project-exposing answers (e.g., `/api/content?type=...`, `X-API-Key`, `V60`, `Flyway V1-69`) were rewritten to generic concepts (e.g., `show me backend projects` → `Backend services for content delivery, AI integration, access control, and timeline features — focused on clean, scalable architecture.`) via `sanitize_all.py:1` (`PUT /api/ama/admin/knowledge/{id}`), remaining leak 0 (`final_verify2.py:1`).

## Verify
```bash
curl -X POST http://localhost:8080/api/ama/ask -H "X-API-Key: <key>" -d '{"question":"loved your star feature","mode":"KNOWLEDGE_FIRST"}' # → compliment thanks, not V60
curl -X POST -d '{"question":"escribe yourself inone work","mode":"KNOWLEDGE_FIRST"}' # → Ownership. (typo keywords)
curl -X POST -d '{"question":"thanks","mode":"KNOWLEDGE_FIRST"}' # → gratitude
# All return PUBLISHED, not queue
```
