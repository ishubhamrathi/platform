# Ask Me Anything (AMA) API

The AMA engine serves the public "Ask Me Anything" widget and the admin review/curation UI. It is
**embedded in the platform backend** via the `ama-spring-boot-starter` Maven package
(`com.opencv.ama:ama-spring-boot-starter:1.0.0`), which auto-configures the controllers and a JDBC
store on the platform's own PostgreSQL schema (`platform`). All endpoints below are relative to the
platform backend host.

- Public endpoints are gated by the platform's API-key/access-rule layer (`X-API-Key` header +
  `api_access_rules`); open paths are declared in `api-access.yaml` (`POST /api/ama/ask`,
  `GET /api/ama/questions/**`, `GET /api/ama/health`).
- Admin endpoints require the platform's `ADMIN` role (same session/HTTP Basic auth as the rest of
  the admin backend) — they are **not** open in `api-access.yaml`.
- The engine's tables (`ama_questions`, `ama_answers`, `ama_knowledge`) are created by Flyway
  (`V64__Create_Ama_Tables.sql`); the starter's own DDL auto-creation is disabled
  (`ama.jdbc.ddl-enabled: false`).
- Content-Type for requests: `application/json; charset=utf-8`
- Timestamps are ISO-8601 instants in UTC, e.g. `"2026-08-13T07:31:47.290356Z"`
- Errors always have the shape `{ "error": "..." }`

## Workflow modes

A question is turned into an answer according to its workflow mode:

| Mode               | Behaviour                                                                                                |
|--------------------|----------------------------------------------------------------------------------------------------------|
| `AUTO`             | Provider chain answers immediately; answer is published.                                                  |
| `REVIEW`           | Provider chain drafts an answer that stays hidden until an admin approves it.                             |
| `MANUAL`           | No AI; the question is queued for an admin-written answer.                                                |
| `KNOWLEDGE_FIRST`  | Knowledge base matched first; on a strong enough match it publishes directly, otherwise follows `ai-mode`.|

If the client omits `mode`, the server uses its configured `default-mode`.

## Question statuses

| Status      | Meaning                                                                 |
|-------------|-------------------------------------------------------------------------|
| `NEW`       | Created, not yet processed.                                             |
| `DRAFT`     | AI answer exists but is hidden pending admin approval.                  |
| `PENDING`   | Queued for a human answer (no publishable answer yet).                  |
| `PUBLISHED` | A visible answer exists; the asker may fetch it.                        |
| `REJECTED`  | Admin declined the question.                                            |
| `ARCHIVED`  | Hidden from default lists; used for cleanup.                            |

Answer `source` values: `KNOWLEDGE`, `AI`, `HUMAN`.

---

## Public Endpoints (platform API-key access)

Requests must carry the platform `X-API-Key` header for a project that has an active rule covering
the path (e.g. `portfolio` → `/api/ama/**`). Unknown/missing keys return `403`. Fields and payloads
are otherwise unchanged.

### Ask a question

```
POST /api/ama/ask
Content-Type: application/json
```

**Request body**

| Field        | Type   | Required | Description                                                  |
|--------------|--------|----------|--------------------------------------------------------------|
| `question`   | string | **yes**  | The visitor's question. Max 1000 chars, trimmed.             |
| `askerName`  | string | no       | Visitor's name (max 120 chars).                              |
| `askerEmail` | string | no       | Optional email for follow-up; must contain `@` if provided.  |
| `category`   | string | no       | Free-form category; normalised server-side (`general` if blank). |
| `mode`       | string | no       | One of `AUTO`, `REVIEW`, `MANUAL`, `KNOWLEDGE_FIRST`. Defaults to server config. |

```json
{
  "question": "What tech stack do you use?",
  "askerName": "Jane",
  "askerEmail": "jane@example.com",
  "category": "work",
  "mode": "MANUAL"
}
```

**Response `200 OK`**

```json
{
  "reference": "qxw4iYZo",
  "questionId": "b0557f66-c441-4bc6-92a6-e6955adac0fd",
  "status": "PENDING",
  "mode": "MANUAL",
  "answered": false,
  "answer": null,
  "message": "Thanks — your question is in the queue and will be answered soon."
}
```

| Field        | Type     | Description                                                                           |
|--------------|----------|---------------------------------------------------------------------------------------|
| `reference`  | string   | Short, public lookup key (8 chars). Poll with `GET /api/ama/questions/{reference}`.    |
| `questionId` | string   | Internal UUID. Use it for admin endpoints.                                            |
| `status`     | string   | Resulting question status.                                                            |
| `mode`       | string   | Effective workflow mode.                                                              |
| `answered`   | boolean  | `true` when a published answer is immediately available (AUTO / knowledge hit).        |
| `answer`     | string   | The answer text when `answered` is `true`, otherwise `null`.                           |
| `message`    | string   | Human-friendly status line; safe to display as-is.                                    |

When `status` is `DRAFT` or `PENDING`, no answer is returned yet — the frontend should poll
`GET /api/ama/questions/{reference}` until `status` is `PUBLISHED`.

**Response `400 Bad Request`**

```json
{ "error": "Question cannot be empty" }
```
Also returned for: invalid email, unknown `mode`, or hitting the per-IP rate limit
(`"Too many questions. Please try again later."`).

**Response `503 Service Unavailable`** — `AUTO`/`REVIEW` mode but no provider could produce an answer

```json
{ "error": "Answering is temporarily unavailable. Please try again later." }
```

### Poll a question's status / answer

```
GET /api/ama/questions/{reference}
```

**Response `200 OK`**

```json
{
  "reference": "qxw4iYZo",
  "status": "PUBLISHED",
  "mode": "MANUAL",
  "question": "What tech stack do you use?",
  "createdAt": "2026-08-13T07:31:47.290356Z",
  "answeredAt": "2026-08-13T07:35:02.100000Z",
  "answer": "Mostly Java, Spring Boot, and a bit of Kotlin."
}
```

| Field        | Type     | Description                                                        |
|--------------|----------|--------------------------------------------------------------------|
| `reference`  | string   | The question reference (echoes the URL segment).                   |
| `status`     | string   | Current status (see status table).                                 |
| `mode`       | string   | Workflow mode.                                                     |
| `question`   | string   | The original question text.                                        |
| `createdAt`  | string   | ISO-8601 creation timestamp.                                       |
| `answeredAt` | string   | ISO-8601 publish timestamp, or `null` if not published.            |
| `answer`     | string   | Published answer text, or `null` until the question is `PUBLISHED`.|

**Response `400 Bad Request`** — unknown reference

```json
{ "error": "Unknown reference: XXXXXXXX" }
```

### Provider health

```
GET /api/ama/health
```

**Response `200 OK`**

```json
{
  "providers": [
    { "name": "openai", "available": false }
  ]
}
```

`available` is `true` when the provider is enabled and configured. Useful to decide whether to show
the ask widget at all.

---

## Admin Endpoints (require ADMIN role)

Admin endpoints are under the configurable base path configured in `application.yaml`
(`ama.admin.base-path: /api/ama/admin`). Authenticate with the platform's `ADMIN` session
(form-login) or HTTP Basic (`Authorization: Basic ...`). For browser calls use
`withCredentials: true`.

### List questions

```
GET /api/ama/admin/questions?status=DRAFT&mode=AUTO&q=stack&page=0&size=20
```

| Query param | Type   | Description                                                        |
|-------------|--------|--------------------------------------------------------------------|
| `status`    | string | Repeatable filter, e.g. `?status=DRAFT&status=PENDING`. Empty = all.|
| `mode`      | string | Repeatable filter, e.g. `?mode=AUTO&mode=REVIEW`. Empty = all.     |
| `q`         | string | Loose text search over the question text.                          |
| `page`      | number | Zero-based page (default `0`).                                     |
| `size`      | number | Page size (default `20`, max `100`).                               |

**Response `200 OK`**

```json
{
  "items": [
    {
      "id": "b0557f66-c441-4bc6-92a6-e6955adac0fd",
      "reference": "qxw4iYZo",
      "askerName": "Jane",
      "askerEmail": "jane@example.com",
      "question": "What tech stack do you use?",
      "category": "work",
      "mode": "MANUAL",
      "status": "PENDING",
      "createdAt": "2026-08-13T07:31:47.290356Z",
      "answeredAt": null,
      "answer": null
    }
  ],
  "total": 1,
  "page": 0,
  "size": 20
}
```

`answer` is the **latest** answer (including unpublished AI drafts) — admin UI can render it for review.
`answer` shape:

| Field        | Type     | Description                                   |
|--------------|----------|-----------------------------------------------|
| `content`    | string   | Answer text.                                  |
| `source`     | string   | `KNOWLEDGE` \| `AI` \| `HUMAN`.               |
| `provider`   | string   | Provider name (e.g. `openai`) or `admin`.     |
| `model`      | string   | Model used, or `null`.                        |
| `confidence` | number   | 0–1 score, or `null`.                         |
| `approvedBy` | string   | Reviewer name, or `null`.                     |
| `approvedAt` | string   | ISO-8601 approval time, or `null`.            |

### Get a single question

```
GET /api/ama/admin/questions/{id}
```
Same `QuestionView` object as above. **`404`** when not found: `{ "error": "Question not found: {id}" }`.

### Approve an AI draft

```
POST /api/ama/admin/questions/{id}/approve
Content-Type: application/json
```

**Request body** (both optional)

```json
{ "editedAnswer": "Optional edited text, or omit to keep the AI draft", "approvedBy": "admin" }
```

Publishes the question. When `editedAnswer` is present it replaces the AI draft with a `HUMAN`
answer. **Response `200 OK`** — updated `QuestionView`.

### Write / publish a manual answer

```
POST /api/ama/admin/questions/{id}/answer
Content-Type: application/json
```

**Request body**

| Field        | Type   | Required | Description                |
|--------------|--------|----------|----------------------------|
| `content`    | string | **yes**  | Answer text to publish.    |
| `approvedBy` | string | no       | Reviewer name (default `admin`). |

```json
{ "content": "Mostly Java, Spring Boot, and a bit of Kotlin.", "approvedBy": "admin" }
```

Overwrites any existing answer and publishes immediately. **Response `200 OK`** — updated `QuestionView`.
**`400`** when `content` is blank.

### Reject / archive / delete

```
POST   /api/ama/admin/questions/{id}/reject
POST   /api/ama/admin/questions/{id}/archive
DELETE /api/ama/admin/questions/{id}
```

Reject/archive return the updated `QuestionView` (`200`). Delete returns `204 No Content`
(really deletes the row; the answer cascade-deletes).

### Stats

```
GET /api/ama/admin/stats
```

**Response `200 OK`**

```json
{
  "total": 12,
  "byStatus": {
    "NEW": 0, "DRAFT": 3, "PENDING": 2, "PUBLISHED": 6, "REJECTED": 1, "ARCHIVED": 0
  },
  "publishedLast7Days": 4
}
```

### Provider status

```
GET /api/ama/admin/providers
```

Same shape as the public `/api/ama/health`.

### Knowledge base

The knowledge base is curated Q&A used by `KNOWLEDGE_FIRST` and as context for AI answers.

#### List

```
GET /api/ama/admin/knowledge
```

**Response `200 OK`**

```json
[
  {
    "id": "8f2d1c3e-...",
    "category": "work",
    "question": "What tech stack do you use?",
    "answer": "Java, Spring Boot, PostgreSQL, React.",
    "keywords": ["stack", "java", "react"],
    "confidence": 0.9,
    "active": true
  }
]
```

#### Create

```
POST /api/ama/admin/knowledge
Content-Type: application/json
```

**Request body**

| Field        | Type     | Required | Description                                 |
|--------------|----------|----------|---------------------------------------------|
| `category`   | string   | no       | Normalised server-side (`general` if blank).|
| `question`   | string   | **yes**  | Canonical question (≤ 500 chars).           |
| `answer`     | string   | **yes**  | Answer text.                                |
| `keywords`   | string[] | no       | Search tokens that boost matching.          |
| `confidence` | number   | no       | 0–1 default confidence for this entry.      |
| `active`     | boolean  | no       | Defaults to `true`.                         |

**Response `200 OK`** — created `KnowledgeView` (includes server-generated `id`).

#### Update

```
PUT /api/ama/admin/knowledge/{id}
Content-Type: application/json
```

Same body as create; every field optional (absent fields keep current values).
**Response `200 OK`** — updated `KnowledgeView`. **`404`** when not found.

#### Delete

```
DELETE /api/ama/admin/knowledge/{id}
```
**Response `204 No Content`**. **`404`** when not found.

---

## Error responses

| HTTP status | When                                                              | Body                                    |
|-------------|-------------------------------------------------------------------|-----------------------------------------|
| `400`       | Bad input (blank question, bad email, unknown mode, rate limited, blank answer, unknown reference) | `{ "error": "..." }` |
| `401`       | Admin endpoint without valid credentials                          | (security filter)                       |
| `404`       | Question/knowledge entry not found                                | `{ "error": "..." }` |
| `503`       | No AI provider could produce an answer                            | `{ "error": "Answering is temporarily unavailable. ..." }` |
| `500`       | Unexpected failure                                                | `{ "error": "..." }` |

---

## Critical Rules

- **Reference vs id**: `reference` is the short public key for `GET /api/ama/questions/{reference}`;
  `questionId`/`id` is the internal UUID used by admin endpoints. Never expose admin ids in public URLs.
- **Answers are hidden until published**: the public poll returns `answer: null` unless `status` is `PUBLISHED`.
- **Rate limiting**: public asks are limited per client IP (default 20/hour). Behind a proxy the server
  reads the first hop of `X-Forwarded-For`.
- **Admin auth**: all `/api/ama/admin/**` calls require the platform `ADMIN` session (form login or
  HTTP Basic) — the demo app's `AMA_ADMIN_PASSWORD` does not apply here.
- **Admin base path**: configured in `application.yaml` via `ama.admin.base-path`
  (default `/api/ama/admin`).
- **CORS**: handled by the platform backend's standard CORS configuration like any other endpoint.
