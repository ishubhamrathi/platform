# AMA Suggestions API

Admin API for managing suggested questions shown to visitors in the AMA (Ask Me
Anything) widget. Suggestions guide visitors by showing pre-defined questions
they can click to ask.

Base URL: `VITE_API_BASE` (default `http://localhost:8080`).

## Authentication

Admin endpoints require **admin authentication** (`ADMIN` role). Session-based
auth via `/api/auth/login`. The public endpoint requires no authentication.

## Endpoints

| Method   | Endpoint                              | Auth     | Description                    |
|----------|---------------------------------------|----------|--------------------------------|
| `GET`    | `/api/suggestions`                    | Public   | List active suggestions        |
| `GET`    | `/api/admin/ama/suggestions`          | Admin    | List all suggestions           |
| `POST`   | `/api/admin/ama/suggestions`          | Admin    | Create a suggestion            |
| `PUT`    | `/api/admin/ama/suggestions/{id}`     | Admin    | Update a suggestion            |
| `DELETE` | `/api/admin/ama/suggestions/{id}`     | Admin    | Delete a suggestion            |

---

## `GET /api/suggestions`

Public endpoint for visitors. Returns only **active** suggestions sorted by
`display_order`.

**Response `200 OK`**

```json
{
  "items": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "question": "What technologies do you use?",
      "category": "tech",
      "displayOrder": 1,
      "active": true
    }
  ],
  "total": 12
}
```

---

## `POST /api/admin/ama/suggestions`

Creates a new suggestion.

**Request body**

| Field          | Type    | Required | Description                          |
|----------------|---------|----------|--------------------------------------|
| `question`     | string  | yes      | The suggested question text          |
| `category`     | string  | no       | Category for grouping (e.g. "tech") |
| `displayOrder` | number  | no       | Sort order (lower = first)           |
| `active`       | boolean | no       | Show to visitors (default `true`)    |

```json
{
  "question": "What technologies do you use?",
  "category": "tech",
  "displayOrder": 1,
  "active": true
}
```

**Response `200 OK`**

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "created": true
}
```

**Response `400 Bad Request`** — question is required

```json
{ "error": "question is required", "hint": null }
```

---

## `PUT /api/admin/ama/suggestions/{id}`

Updates an existing suggestion.

**Path parameters**

| Parameter | Description         |
|-----------|---------------------|
| `id`      | Suggestion UUID     |

**Request body** — same as `POST`

```json
{
  "question": "Updated question text",
  "category": "tech",
  "displayOrder": 2,
  "active": true
}
```

**Response `200 OK`**

```json
{ "updated": true }
```

**Response `404 Not Found`**

```json
{ "error": "Suggestion not found", "hint": null }
```

---

## `DELETE /api/admin/ama/suggestions/{id}`

Deletes a suggestion permanently.

**Path parameters**

| Parameter | Description         |
|-----------|---------------------|
| `id`      | Suggestion UUID     |

**Response `200 OK`**

```json
{ "deleted": true }
```

**Response `404 Not Found`**

```json
{ "error": "Suggestion not found", "hint": null }
```

---

## Database Schema

**Table: `ama_suggestions`**

| Column         | Type         | Default             | Description                    |
|----------------|--------------|---------------------|--------------------------------|
| `suggestion_id`| UUID (PK)    | `gen_random_uuid()` | Unique identifier              |
| `question`     | TEXT         | —                   | The suggested question text    |
| `category`     | VARCHAR(100) | NULL                | Category for grouping          |
| `display_order`| INT          | 0                   | Sort order (ascending)         |
| `active`       | BOOLEAN      | TRUE                | Whether shown to visitors      |
| `created_at`   | TIMESTAMPTZ  | `now()`             | Creation timestamp             |
| `updated_at`   | TIMESTAMPTZ  | `now()`             | Last modification timestamp    |

**Indexes:**
- `idx_ama_suggestions_active` — on `(active, display_order)` for fast visitor queries

---

## Visitor-Facing Widget

Suggestions are displayed in the AMA widget on the portfolio site. The visitor
widget queries **active suggestions only** and displays them in `display_order`.

**Flow:**
1. Visitor opens AMA widget
2. Widget fetches active suggestions
3. Visitor clicks a suggestion → question is submitted
4. Admin can optionally "train" the suggestion into the knowledge base

---

## Admin Widget (BDUI)

Entity code: `ASG`

Widget template: `templates/widgets/ama-suggestions.yaml`

The admin widget provides a console for managing suggestions with:
- List view with all suggestions
- Create/edit forms
- Toggle active/inactive
- Reorder via `displayOrder`
- Delete capability
- "Train to knowledge" action (copies suggestion to knowledge base)

---

## Critical Rules

- **Admin only** — all endpoints require `ADMIN` role authentication.
- **Question required** — `question` field cannot be blank on create/update.
- **Soft delete recommended** — set `active: false` before deleting to preserve
  any linked knowledge base entries.
- **Display order** — lower numbers appear first; default is 0.
- **Category grouping** — use categories to organize suggestions (e.g., "tech",
  "portfolio", "general").
