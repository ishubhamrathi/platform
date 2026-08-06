# Inbox API

## Public Endpoints (no auth)

### List contact categories

```
GET /api/contact/categories
```

**Response `200 OK`**

```json
{
  "categories": [
    { "code": "general", "label": "General Inquiry" },
    { "code": "feedback_portfolio", "label": "Portfolio Feedback", "path": "feedback/portfolio" },
    { "code": "feedback_blog", "label": "Blog Feedback", "path": "feedback/blog" },
    { "code": "support", "label": "Support Request" },
    { "code": "sales", "label": "Sales / Partnership" }
  ],
  "count": 5
}
```

### Submit a message

```
POST /api/contact
Content-Type: application/json
```

**Request body**

| Field          | Type   | Required | Description                                      |
|----------------|--------|----------|--------------------------------------------------|
| `sender_name`  | string | no       | Visitor's name                                   |
| `sender_email` | string | **yes**  | Visitor's email                                  |
| `subject`      | string | no       | Message subject                                  |
| `message`      | string | **yes**  | Message body                                     |
| `category`     | string | no       | Category code from `/categories` (see above)     |

**Response `200 OK`**

```json
{
  "id": "432e7a96-...",
  "received": true,
  "is_read": false,
  "is_starred": false,
  "category": "General Inquiry",
  "category_path": "general",
  "created_at": "2025-01-15T10:30:00",
  "created_by": "public-submission"
}
```

**Response `400 Bad Request`** — missing/invalid `sender_email` or `message`

Validation (in order):
- `sender_email` required, ≤ 255 chars, must match `^[^@\s]+@[^@\s]+\.[^@\s]+$`
- `message` required, ≤ 10,000 chars
- `sender_name` ≤ 255 chars
- `subject` ≤ 300 chars

```json
{ "error": "sender_email is required", "hint": null }
```

**Response `500 Internal Server Error`** — submission failed

```json
{ "error": "Failed to submit message", "hint": null }
```

---

## Admin Endpoints (require ADMIN session)

Entity code: **INB** → table `inbox`

| Method   | Endpoint                      | Description                          |
|----------|-------------------------------|--------------------------------------|
| `POST`   | `/api/v1/data/INB`            | Create inbox message                 |
| `GET`    | `/api/v1/data/INB/{uuid}`     | Get single inbox message             |
| `PUT`    | `/api/v1/data/INB/{uuid}`     | Update inbox message fields          |
| `DELETE` | `/api/v1/data/INB/{uuid}`     | Soft-delete inbox message            |

### Inbox table schema

| Column          | Type    | Client-visible | Description                          |
|-----------------|---------|----------------|--------------------------------------|
| `inbox_id`      | UUID    | hidden         | PK (auto-generated)                  |
| `sender_name`   | string  | editable       | Sender name                          |
| `sender_email`  | string  | editable       | Sender email                         |
| `subject`       | string  | editable       | Message subject                      |
| `message`       | text    | editable       | Message body (richtext in widget)    |
| `is_read`       | boolean | toggle         | Read status                          |
| `is_starred`    | boolean | toggle         | Starred status                       |
| `is_archived`   | boolean | toggle         | Archived status (auto-set by action)  |
| `category`      | string  | editable       | Display category (e.g. "General Inquiry") |
| `category_path` | string  | editable       | Hierarchical path (e.g. "general")    |
| `created_at`    | datetime| readonly       | Created timestamp                    |
| `updated_at`    | datetime| readonly       | Last updated timestamp               |

### Create inbox message

```
POST /api/v1/data/INB
Content-Type: application/json
```

**Request body** — any non-system column from the schema above

```json
{
  "sender_name": "Jane Doe",
  "sender_email": "jane@example.com",
  "subject": "Portfolio feedback",
  "message": "Love the design!",
  "category": "Portfolio Feedback"
}
```

**Response `201 Created`**

```json
{ "id": "5117381b-..." }
```

### Get single inbox message

```
GET /api/v1/data/INB/{uuid}
```

**Response `200 OK`** — full row as key/value map (PK exposed as `id`)

**Response `404 Not Found`** — record not found or already soft-deleted

```json
{ "error": "Record not found", "hint": null }
```

### Update inbox message

```
PUT /api/v1/data/INB/{uuid}
Content-Type: application/json
```

**Request body** — any subset of editable columns

```json
{
  "is_read": true,
  "is_starred": true
}
```

**Response `200 OK`**

```json
{ "updated": true }
```

**Response `404 Not Found`**

```json
{ "error": "Record not found", "hint": null }
```

### Delete inbox message (soft-delete)

```
DELETE /api/v1/data/INB/{uuid}
```

Stamps `deleted_at` + `deleted_by`; the row stays in the database but is hidden from queries.

**Response `200 OK`**

```json
{ "deleted": true, "soft": true }
```

**Response `404 Not Found`**

```json
{ "error": "Record not found", "hint": null }
```

---

## Admin Widget: Inbox Table

The admin UI loads the inbox table via:

```
GET /api/v1/widget/INB
```

Returns pagination with searchable columns (`sender_name`, `sender_email`, `subject`, `message`), sortable/filterable columns, and a row action to archive.

### Archive row action

The widget provides a row-level "Archive" action that PUTs to:

```
PUT /api/v1/data/INB/{id}
Content-Type: application/json

{ "is_archived": true }
```

---

## Critical Rules

- **Admin endpoints** require an authenticated session with `ADMIN` role.
- **Soft-delete**: deleting an inbox message marks `deleted_at` / `deleted_by`; the row is automatically excluded from subsequent queries.
- **Public submissions**: `is_read`, `is_starred`, `is_archived`, `deleted_at`, `created_by` are set server-side; client-supplied values for these fields are ignored.
- **Category validation**: if a `category` code is submitted that doesn't match config, it defaults to "General" / "general".
- Use `withCredentials: true` for admin endpoints (session cookie required).
