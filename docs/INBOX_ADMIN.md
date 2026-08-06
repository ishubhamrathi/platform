# Admin Panel: Inbox Widget

## Overview

The inbox widget manages incoming messages submitted via the public contact form (`POST /api/contact`).
Messages live in the `inbox` table (entity code **INB**). The widget is a **table** with a row-level
**Archive** action; read/star/archive toggles and full message details are handled via the
single-record data endpoints.

---

## 1. Load Inbox Widget (Table)

```
GET /api/v1/widget/INB?page=1&pageSize=25&search=john&sortBy=created_at&sortOrder=desc
Cookie: JSESSIONID=<admin_session>
```

| Param | Type | Default | Description |
|---|---|---|---|
| `page` | int | 1 | 1-based page number |
| `pageSize` | int | 25 | Items per page |
| `search` | string | — | Global search: `sender_name`, `sender_email`, `subject`, `message` |
| `sortBy` | string | `created_at` | Sort column |
| `sortOrder` | string | `desc` | `asc` or `desc` |
| `field` | string | — | Filter column name |
| `value` | string | — | Filter value |

### Response `200 OK`

```json
{
  "type": "table",
  "title": "Inbox",
  "subtitle": "Manage incoming messages with sender info, categories, and read/starred status",
  "schema": {
    "columns": [
      { "name": "id", "label": "ID", "type": "uuid", "sortable": true, "filterable": true },
      { "name": "sender_name", "label": "Sender Name", "type": "text", "sortable": true, "filterable": true },
      { "name": "sender_email", "label": "Sender Email", "type": "email", "sortable": true, "filterable": true },
      { "name": "subject", "label": "Subject", "type": "text", "sortable": true, "filterable": true },
      { "name": "message", "label": "Message", "type": "richtext", "sortable": false, "filterable": false },
      { "name": "is_read", "label": "Read", "type": "boolean", "sortable": true, "filterable": true },
      { "name": "is_starred", "label": "Starred", "type": "boolean", "sortable": true, "filterable": true },
      { "name": "is_archived", "label": "Archived", "type": "boolean", "sortable": true, "filterable": true },
      { "name": "category_path", "label": "Category Path", "type": "text", "sortable": true, "filterable": true },
      { "name": "category", "label": "Category", "type": "text", "sortable": true, "filterable": true },
      { "name": "created_at", "label": "Created At", "type": "datetime", "sortable": true, "filterable": false },
      { "name": "updated_at", "label": "Updated At", "type": "datetime", "sortable": true, "filterable": false }
    ]
  },
  "data": [
    {
      "id": "a1b2c3d4-...",
      "sender_name": "Jane Doe",
      "sender_email": "jane@example.com",
      "subject": "Portfolio feedback",
      "message": "Love the new design!",
      "is_read": false,
      "is_starred": false,
      "is_archived": false,
      "category_path": "feedback/portfolio",
      "category": "Portfolio Feedback",
      "created_at": "2025-01-15T10:30:00",
      "updated_at": "2025-01-15T10:30:00"
    }
  ],
  "pagination": { "page": 1, "pageSize": 25, "totalItems": 5, "totalPages": 1 },
  "actions": [
    {
      "id": "archive", "label": "Archive", "type": "confirm",
      "config": {
        "icon": "archive",
        "method": "PUT",
        "url": "/api/v1/data/INB/{id}",
        "body": { "is_archived": true },
        "confirmTitle": "Archive Message?",
        "confirmMessage": "This will archive the message. It stays in the database and remains searchable via filters."
      },
      "permissions": ["ADMIN"]
    }
  ],
  "permissions": ["ADMIN"],
  "metadata": {
    "entityCode": "INB",
    "searchable": true,
    "searchPlaceholder": "Search by sender name, email, subject, or message...",
    "defaultSort": "created_at",
    "defaultSortOrder": "desc",
    "rowActions": ["archive"],
    "tableActions": []
  }
}
```

Notes:
- The row PK is exposed as `id` (the `inbox_id` UUID column) — use it in all CRUD URLs.
- Widget `data` rows come from a `SELECT *` (soft-deleted rows excluded); full `message` text and
  audit columns (`created_by`, `updated_by`, `deleted_at`, `deleted_by`) are present on the row.
- **Unread** rows (`is_read: false`) should be visually distinct (colored dot / bold subject).

---

## 2. Message Detail

Fetch the full message when a row is opened:

```
GET /api/v1/data/INB/{uuid}
Cookie: JSESSIONID=<admin_session>
```

### Response `200 OK`

```json
{
  "id": "a1b2c3d4-...",
  "sender_name": "Jane Doe",
  "sender_email": "jane@example.com",
  "subject": "Portfolio feedback",
  "message": "Love the new design! It's clean and easy to navigate.",
  "is_read": false,
  "is_starred": false,
  "is_archived": false,
  "category_path": "feedback/portfolio",
  "category": "Portfolio Feedback",
  "deleted_at": null,
  "deleted_by": null,
  "created_at": "2025-01-15T10:30:00",
  "created_by": "public-submission",
  "updated_at": "2025-01-15T10:30:00",
  "updated_by": null
}
```

### Response `404 Not Found`

```json
{ "error": "Record not found", "hint": null }
```

---

## 3. Actions

Status updates use `PUT /api/v1/data/INB/{uuid}` with a partial body. Writable columns:
`sender_name`, `sender_email`, `subject`, `message`, `category`, `category_path`, `is_read`,
`is_starred`, `is_archived`.

### Mark read / unread

```
PUT /api/v1/data/INB/{uuid}
Content-Type: application/json

{ "is_read": true }      // or false
```

Response: `{ "updated": true }`

### Toggle starred

```
PUT /api/v1/data/INB/{uuid}
Content-Type: application/json

{ "is_starred": true }   // or false
```

Response: `{ "updated": true }`

### Archive / unarchive

```
PUT /api/v1/data/INB/{uuid}
Content-Type: application/json

{ "is_archived": true }  // or false
```

Response: `{ "updated": true }`

### Delete (soft-delete)

```
DELETE /api/v1/data/INB/{uuid}
```

Response `200 OK`:

```json
{ "deleted": true, "soft": true }
```

Response `404 Not Found`:

```json
{ "error": "Record not found", "hint": null }
```

---

## 4. Filtering

The widget accepts a single `field` + `value` pair per request:

| Filter | Query |
|---|---|
| Unread only | `?field=is_read&value=false` |
| Starred only | `?field=is_starred&value=true` |
| Archived only | `?field=is_archived&value=true` |

---

## 5. Frontend Behavior Checklist

1. **Row → detail**: Clicking a row fetches `GET /api/v1/data/INB/{id}` and opens the detail view.
2. **Read/unread**: Toggle `is_read` via `PUT`; update UI optimistically.
3. **Star**: Toggle `is_starred` via `PUT`.
4. **Archive**: Row action (and detail button) sets `is_archived: true` via `PUT`.
5. **Delete**: Confirmation dialog, then `DELETE /api/v1/data/INB/{id}`.
6. **Auto-refresh**: After any write, refetch the list (`GET /api/v1/widget/INB`).
7. **Unread indicator**: Rows with `is_read: false` show a colored dot and bold subject.
8. **`withCredentials: true`** required for all admin endpoints.
9. **No inline table editing** — read/archive/delete go through the detail view and row actions.
