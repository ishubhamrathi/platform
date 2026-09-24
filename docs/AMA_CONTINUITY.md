# AskAI Continuity — Making Contextual Follow-ups Work

## Problem
The `ama-spring-boot-starter` engine is **stateless per question**: `POST /api/ama/ask` + `GET /api/ama/questions/{reference}` has no `conversationId` or history. So a short follow-up like `more`, `any other projects?`, `what else?` fails because the engine has no memory of the previous `what are your favourite projects?`.

## Solution Overview (No Fork Required)
Handle continuity **client-side in the portfolio chat widget**, and seed the knowledge base with follow-up–aware entries (category `followup` in `scripts/ama-seed-data.json`).

### 1. Knowledge Base Seeded via APIs (386 entries, target 300-500)
No Flyway migration — seeded via `POST /api/ama/admin/knowledge` using `scripts/ama-seed-data.json` (386 entries) + `scripts/ama-suggestions.json`.

Categories: `general`, `backend`, `database`, `frontend`, `ai`, `work`, `personality`, `projects`, `career`, `opinions`, `fun`, `contact`, `followup`, `recruiter`, `tech` — each entry has `category, question, answer, keywords, confidence 0.85-1.0`.

Critical for continuity — `followup` category has 25 entries for:
`more`, `tell me more`, `any other projects?`, `what else?`, `yes`, `another one`, `continue`, `what about backend/frontend/database/AI`, `give an example`, `show me backend/AI projects`, `thanks, what should I ask next?`

These match high thresholds (`0.9–1.0`) so a bare `more` instantly hits a curated answer.

#### How to seed (API-based)
```powershell
# 1. Create admin (once)
# POST /api/auth/register then in DB:
# UPDATE users SET role='ADMIN' WHERE email='you@example.com';

# 2. Run seeder (Node 18+ or PowerShell)
node scripts/seed-ama-knowledge.mjs --api=http://localhost:8080 --email=you@example.com --password=secret
# or
.\scripts\seed-ama-knowledge.ps1 -Email you@example.com -Password secret -ApiBase http://localhost:8080

# Script: logs in (POST /api/auth/login -> SESSION cookie), GET /api/ama/admin/knowledge for dedup, POST missing entries
# Data: scripts/ama-seed-data.json (386) + scripts/ama-suggestions.json (10)
# Expand to 500: add entries to JSON and re-run (dedup by question text handles idempotency)
```

### 2. Frontend Context Expansion (Recommended)
Keep last interaction in memory and **rewrite thin follow-ups** into self-contained queries before calling `POST /api/ama/ask`.

#### Heuristic
- If `userInput` is <= 4 words OR matches `/\b(more|other|else|another|continue|elaborate|details|example|and\?)\b/i` then expand:
  `expanded = "Follow-up to '" + lastQuestion + "': " + userInput + " (Provide more details about " + topic(lastQuestion) + ")"`
- Keep a `history: {role, content}[]` (last 6 turns) to show in UI, but send only the expanded single question to the engine (engine has no multi-turn API).

#### Drop-in React Logic
```ts
// portfolio-frontend/src/hooks/useAskAiChat.ts
import { useState, useRef } from 'react';

type Msg = { role: 'user' | 'assistant'; content: string };

const SHORT_FOLLOW_RE = /\b(more|other|else|another|continue|elaborate|details|example|and\?|what else|any other)\b/i;
const TOPIC_RE = [
  { re: /project|portfolio/i, topic: 'portfolio projects' },
  { re: /backend|spring|jooq|flyway|java/i, topic: 'backend architecture' },
  { re: /frontend|react|typescript/i, topic: 'frontend' },
  { re: /database|postgres|supabase|sql/i, topic: 'database and PostgreSQL optimization' },
  { re: /ai|automation|assistant/i, topic: 'AI and automation' },
  { re: /hire|recruiter|strength/i, topic: 'hiring Shubham' },
  { re: /contact|email/i, topic: 'contacting Shubham' },
];

function detectTopic(q: string) {
  for (const { re, topic } of TOPIC_RE) if (re.test(q)) return topic;
  return q.slice(0, 80);
}

export function useAskAiChat(apiBase: string, apiKey: string) {
  const [messages, setMessages] = useState<Msg[]>([]);
  const lastQ = useRef<string>('');
  const lastA = useRef<string>('');

  async function ask(raw: string) {
    let question = raw.trim();
    const isShortFollow = question.split(/\s+/).length <= 4 && SHORT_FOLLOW_RE.test(question)
                       || SHORT_FOLLOW_RE.test(question) && question.length < 30;

    if (isShortFollow && lastQ.current) {
      // Expand: "more" -> "Tell me more about portfolio projects (follow-up to 'what are your favourite projects?')"
      question = `Tell me more about ${detectTopic(lastQ.current)} (follow-up to '${lastQ.current}': ${raw})`;
    }

    setMessages(m => [...m, { role: 'user', content: raw }]);
    lastQ.current = raw; // keep original for topic detection next turn

    const res = await fetch(`${apiBase}/api/ama/ask`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-API-Key': apiKey },
      body: JSON.stringify({ question, category: 'general', mode: 'KNOWLEDGE_FIRST' }),
    });
    const data = await res.json();
    // KNOWLEDGE_FIRST publishes instantly; otherwise poll:
    let answer = data.answer ?? data.message;
    if (!data.answered && data.reference) {
      for (let i = 0; i < 10; i++) {
        await new Promise(r => setTimeout(r, 800));
        const poll = await fetch(`${apiBase}/api/ama/questions/${data.reference}`, {
          headers: { 'X-API-Key': apiKey },
        }).then(r => r.json());
        if (poll.status === 'PUBLISHED' && poll.answer) { answer = poll.answer; break; }
      }
    }
    setMessages(m => [...m, { role: 'assistant', content: answer }]);
    lastA.current = answer;
    return answer;
  }

  return { messages, ask };
}
```

Usage in chat component:
```tsx
const { messages, ask } = useAskAiChat(import.meta.env.VITE_API_BASE_URL, import.meta.env.VITE_PORTFOLIO_API_KEY);
const onSend = (t: string) => ask(t);
// Render messages; suggestions from GET /api/admin/ama/suggestions or GET /api/ama/admin via platform also work as chips.
```

Flow for the user example:
1. User: `what are your favourite projects?` -> stored as `lastQ`, answer explains portfolio platform.
2. User: `more` -> detected as short follow-up -> expanded to `Tell me more about portfolio projects (follow-up to 'what are your favourite projects?': more)` -> matches `followup` or `projects` entries with `more` keywords -> returns `Any other projects?` / deeper portfolio detail.
3. User: `any other projects` -> again maps to curated `any other projects?` entry listing timeline, star, API console.

### 3. Alternatives (If You Want True Server Memory)
- Enable an AI provider (`ama.providers.openai.enabled=true` + key) and set `ama.default-mode=KNOWLEDGE_FIRST`, `ama.ai-mode=KNOWLEDGE_FIRST` so low-confidence follow-ups fall back to LLM with knowledge entries as context.
- Fork or wrap the starter to add `conversation_id` and history table, then feed prior turns into the prompt. This requires customizing `AmaEngine` — not recommended unless you fork `com.opencv.ama`.

### 4. Admin Curation
Use the admin console widgets:
- `ama-knowledge` -> add/edit Q&A (threshold 0.6)
- `ama-suggestions` -> chips shown under chat input (now seeded with 8 richer prompts)
- `ama-questions` -> approve/reject drafts when `mode=REVIEW`

### 5. Verification (API)
```bash
# Admin verification
curl -c cookies.txt -X POST http://localhost:8080/api/auth/login -H "Content-Type: application/json" -d '{"email":"you@example.com","password":"secret"}'
curl -b cookies.txt http://localhost:8080/api/ama/admin/knowledge | jq length          # expect 395 (9 original + 386) then filter dupes ~386 new
curl -b cookies.txt http://localhost:8080/api/ama/admin/knowledge | jq 'group_by(.category) | map({category:.[0].category, count:length})'

# Public continuity test (needs X-API-Key for portfolio project)
curl -X POST http://localhost:8080/api/ama/ask -H "X-API-Key: <portfolio-key>" -H "Content-Type: application/json" -d '{"question":"what are your favourite projects?","mode":"KNOWLEDGE_FIRST"}'
curl -X POST http://localhost:8080/api/ama/ask -H "X-API-Key: <portfolio-key>" -H "Content-Type: application/json" -d '{"question":"more","mode":"KNOWLEDGE_FIRST"}'
curl -X POST http://localhost:8080/api/ama/ask -H "X-API-Key: <portfolio-key>" -H "Content-Type: application/json" -d '{"question":"any other projects?","mode":"KNOWLEDGE_FIRST"}'
curl -X POST http://localhost:8080/api/ama/ask -H "X-API-Key: <portfolio-key>" -H "Content-Type: application/json" -d '{"question":"tell me more about backend architecture","mode":"KNOWLEDGE_FIRST"}'
# All should return answered=true instantly from knowledge base
```

### 6. Future Seed Growth
To reach 500, append entries to `scripts/ama-seed-data.json` (keep `{category, question, answer, keywords, confidence, active}`) and re-run the seeder — it dedups by lowercased `question`, so re-runs are idempotent. Add 30 more per `top_category` (FRONTEND/BACKEND/AI_ML) for portfolio depth.

