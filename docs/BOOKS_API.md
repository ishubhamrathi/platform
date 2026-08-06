# Books API (Personal Reading Library)

## Overview

Books are managed in **Admin → Books** (entity code `BKS`) and showcased on the
portfolio site as a hobby reading list. Visitors can browse books, see cover
images, and follow Google Books links.

- **Admin CRUD**: `/api/v1/widget/BKS` + `/api/v1/data/BKS/{uuid}`
 - **Authenticated read**: `GET /api/content?type=books` (requires `X-API-Key` header)

---

## 1. Public API

### List all content types or just books

```
GET /api/content?type=books          → books only
GET /api/content?type=books,socials  → books + socials
GET /api/content                     → all content types
```

No auth required (PUBLIC).

### Response for `?type=books`

```json
{
  "books": [
    {
      "id": "a1b2c3d4-...",
      "title": "Clean Code",
      "author": "Robert C. Martin",
      "description": "A handbook of agile software craftsmanship.",
      "coverUrl": "https://covers.openlibrary.org/b/id/8471961-L.jpg",
      "genre": "Software Engineering",
      "googleLink": "https://books.google.com/books?id=23iAl3JY9rAC",
      "isFeatured": true,
      "displayOrder": 0,
      "createdAt": "2025-01-15T10:30:00.000+00:00",
      "updatedAt": "2025-01-15T10:30:00.000+00:00"
    }
  ],
  "count": 1
}
```

### Single-book detail (fallback)

```
GET /api/v1/data/BKS/{uuid}
Cookie: SESSION=<admin_session>
```

> Not publicly accessible — admin session required. For public single-book
> views, use the `?books_limit=N` param or filter client-side.

### Query params

| Param | Description |
|---|---|
| `?type=books` | Return only books content type |
| `?books_limit=N` | Limit number of books returned (max 100, default 50) |

---

## 2. Admin Widget

### Load widget schema + initial data

```
GET /api/v1/widget/BKS?page=1&pageSize=20&search=clean&sortBy=display_order&sortOrder=asc
Cookie: SESSION=<admin_session>
```

| Param | Type | Default | Description |
|---|---|---|---|
| `page` | int | 1 | 1-based page number |
| `pageSize` | int | 25 | Items per page |
| `search` | str | — | Global search: `title`, `author`, `genre` |
| `sortBy` | str | `display_order` | Sort column |
| `sortOrder` | str | `asc` | `asc` or `desc` |
| `field` | str | — | Filter column name |
| `value` | str | — | Filter value |

**Response `200 OK`**

```json
{
  "type": "table",
  "title": "Books",
  "subtitle": "Manage personal reading library entries for the portfolio site.",
  "schema": {
    "columns": [
      { "name": "id", "label": "ID", "type": "uuid", "sortable": true, "filterable": true },
      { "name": "title", "label": "Title", "type": "text", "sortable": true, "filterable": true },
      { "name": "author", "label": "Author", "type": "text", "sortable": true, "filterable": true },
      { "name": "genre", "label": "Genre", "type": "text", "sortable": true, "filterable": true },
      { "name": "cover_url", "label": "Cover URL", "type": "url", "sortable": false, "filterable": false },
      { "name": "google_link", "label": "Google Books", "type": "url", "sortable": false, "filterable": false },
      { "name": "is_featured", "label": "Featured", "type": "boolean", "sortable": true, "filterable": true },
      { "name": "is_active", "label": "Active", "type": "boolean", "sortable": true, "filterable": true },
      { "name": "display_order", "label": "Display Order", "type": "number", "sortable": true, "filterable": false },
      { "name": "created_at", "label": "Created", "type": "datetime", "sortable": true, "filterable": false },
      { "name": "updated_at", "label": "Updated", "type": "datetime", "sortable": true, "filterable": false }
    ]
  },
  "data": [ { ...book row... } ],
  "pagination": { "page": 1, "pageSize": 20, "totalItems": 5, "totalPages": 1 },
  "actions": [
    { "id": "create-book", "label": "Add Book", "type": "modal", "config": { "icon": "plus" }, "permissions": ["ADMIN"] },
    { "id": "edit-book", "label": "Edit", "type": "drawer", "config": { "icon": "pencil" }, "permissions": ["ADMIN"] },
    { "id": "delete-book", "label": "Delete", "type": "confirm", "config": { "icon": "trash" }, "permissions": ["ADMIN"] }
  ],
  "permissions": ["ADMIN"],
  "metadata": {
    "entityCode": "BKS",
    "searchable": true,
    "searchPlaceholder": "Search books by title, author, or genre...",
    "defaultSort": "display_order"
  }
}
```

---

## 3. Admin CRUD Endpoints

All require `Cookie: SESSION=<admin_session>` (ADMIN role).

### Get single book

```
GET /api/v1/data/BKS/{uuid}
```

Returns full row as key/value map.

### Create book

```
POST /api/v1/data/BKS
Content-Type: application/json

{
  "title": "Clean Code",
  "author": "Robert C. Martin",
  "description": "A handbook of agile software craftsmanship.",
  "cover_url": "https://covers.openlibrary.org/b/id/8441961-L.jpg",
  "genre": "Software Engineering",
  "google_link": "https://books.google.com/books?id=23iAl3JY9rAC",
  "is_featured": true,
  "display_order": 0,
  "is_active": true
}
```

Response `201 Created`:

```json
{ "id": "uuid-..." }
```

### Update book

```
PUT /api/v1/data/BKS/{uuid}
Content-Type: application/json

{
  "is_featured": false,
  "display_order": 5
}
```

Response `200 OK`:

```json
{ "updated": true }
```

### Delete book

```
DELETE /api/v1/data/BKS/{uuid}
```

Response `200 OK`:

```json
{ "deleted": true }
```

---

## 4. Book Schema

| Column | Type | Required | Description |
|---|---|---|---|
| `book_id` | UUID | auto | Primary key (auto-generated) |
| `title` | varchar(255) | **yes** | Book title |
| `author` | varchar(255) | **yes** | Author name |
| `description` | text | no | Short description/summary |
| `cover_url` | varchar(500) | no | Cover image URL (for frontend `<img>` rendering) |
| `genre` | varchar(100) | no | Genre/category (e.g. "Fiction", "Software Engineering", "Science Fiction") |
| `google_link` | varchar(500) | no | Google Books URL |
| `is_featured` | boolean | default false | Show on homepage featured section |
| `is_active` | boolean | default true | Only active books appear in public API |
| `display_order` | int | default 0 | Sort order for public display |
| `created_at` | timestamp | auto | Creation timestamp |
| `updated_at` | timestamp | auto | Last updated timestamp |
| `created_by` | varchar(255) | auto | Admin who created |
| `updated_by` | varchar(255) | auto | Admin who last updated |

---

## 5. Frontend Integration Guide

### Suggested genres

Populate the `genre` field as a free-text or use a dropdown with common values:

- Fiction
- Non-Fiction
- Science Fiction
- Fantasy
- Mystery / Thriller
- Biography / Memoir
- Software Engineering
- Programming
- Design
- Business
- Self-Help
- History
- Science
- Philosophy

### Cover image rendering

```html
<!-- Render cover image from cover_url -->
<img
  src={book.coverUrl}
  alt={`${book.title} cover`}
  class="book-cover"
  onerror="this.src='/placeholder-book-cover.png'"
/>

<!-- Google Books button -->
<a href={book.googleLink} target="_blank" rel="noreferrer">
  View on Google Books
</a>
```

### Featured section

Filter `is_featured === true` books for a homepage carousel or featured section.

### Display order

Sort by `displayOrder` ascending, then `title` alphabetical.

### withCredentials

All admin endpoints require `withCredentials: true` in fetch requests:

```js
fetch("/api/v1/widget/BKS", {
  credentials: "include",
});
```
