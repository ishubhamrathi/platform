# Frontend Integration Guide: Footer Social Links (Admin → Socials)

## Overview

Social links are managed in **Admin → Socials** (entity code `SOC`).  
They power the website footer and are served via `GET /api/content?type=socials` (requires `X-API-Key` header).

Admin CRUD uses the generic BDUI endpoints (`/api/v1/widget/SOC` + `/api/v1/data/SOC`).  
Public read uses the consolidated endpoint (`GET /api/content?type=socials`).

**Icons are NOT stored in the database.** They are resolved dynamically from the
platform catalog (`catalog.yaml`) based on the `name` field at read time. The
frontend uses `metadata.platform_icon_map` to preview icons before saving.

---

## 1. Admin Table Widget

### Load widget schema + initial data

```
GET /api/v1/widget/SOC?page=1&pageSize=20&search=github&sortBy=display_order&sortOrder=asc
Cookie: JSESSIONID=<admin_session>
```

| Param | Type | Default | Description |
|---|---|---|---|
| `page` | int | 1 | 1-based page number |
| `pageSize` | int | 25 | Items per page |
| `search` | string | — | Global search across `name`, `link` |
| `sortBy` | string | `display_order` | Sort column |
| `sortOrder` | string | `asc` | `asc` or `desc` |
| `field` | string | — | Filter column name |
| `value` | string | — | Filter value |

### Response

```json
{
  "type": "table",
  "title": "Socials",
  "subtitle": "Manage footer social links (name, link, icon) for the website footer.",
  "schema": {
    "columns": [
      { "name": "id", "label": "ID", "type": "uuid", "sortable": true, "filterable": true },
      {
        "name": "category",
        "label": "Category",
        "type": "select",
        "sortable": true,
        "filterable": true,
        "options": [
          { "value": "SOCIAL", "label": "Social" },
          { "value": "CODING_PROFILE", "label": "Coding Profile" }
        ],
        "default": "SOCIAL"
      },
      {
        "name": "name",
        "label": "Name",
        "type": "select",
        "sortable": true,
        "filterable": true,
        "options": [
          { "value": "GITHUB", "label": "GitHub" },
          { "value": "X", "label": "X" }
        ],
        "previewFrom": "platform_icon_map"
      },
      { "name": "link", "label": "Link", "type": "url", "sortable": false, "filterable": false },
      { "name": "display_order", "label": "Display Order", "type": "number", "sortable": true, "filterable": false },
      { "name": "is_active", "label": "Active", "type": "boolean", "sortable": true, "filterable": true },
      { "name": "updated_at", "label": "Updated At", "type": "datetime", "sortable": true, "filterable": false }
    ]
  },
  "data": [
    {
      "id": "a1b2c3d4-...",
      "name": "GITHUB",
      "link": "https://github.com/edit-test",
      "display_order": 0,
      "category": "SOCIAL",
      "is_active": true,
      "updated_at": "2026-08-03T13:40:00.000+00:00"
    }
  ],
  "pagination": { "page": 1, "pageSize": 20, "totalItems": 1, "totalPages": 1 },
  "actions": [
    { "id": "create", "label": "Add Social Link", "type": "modal", "config": { "icon": "plus" }, "permissions": ["ADMIN"] },
    { "id": "edit", "label": "Edit", "type": "drawer", "config": { "icon": "pencil" }, "permissions": ["ADMIN"] },
    { "id": "delete", "label": "Delete", "type": "confirm", "config": { "icon": "trash" }, "permissions": ["ADMIN"] }
  ],
  "permissions": ["ADMIN"],
  "metadata": {
    "entityCode": "SOC",
    "searchable": true,
    "searchPlaceholder": "Search by name or link...",
    "defaultSort": "display_order",
    "platform_icon_map": {
      "GITHUB": "{\"default\":\"https://cdn.simpleicons.org/github\",\"line\":\"https://cdn.simpleicons.org/github\",\"monochrome\":\"https://cdn.simpleicons.org/github\",\"normal\":\"https://cdn.simpleicons.org/github\",\"filled\":\"https://cdn.simpleicons.org/github\"}",
      "X": "{\"default\":\"https://cdn.simpleicons.org/x\",\"line\":\"https://cdn.simpleicons.org/x\",\"monochrome\":\"https://cdn.simpleicons.org/x\",\"normal\":\"https://cdn.simpleicons.org/x\",\"filled\":\"https://cdn.simpleicons.org/x\"}",
      ...
    }
  }
}
```

### Two-step selection flow

1. **Category dropdown** — select `SOCIAL` or `CODING_PROFILE` first
2. **Name dropdown** — select platform (e.g. `GITHUB`, `X`). When selected:
   - Frontend parses `metadata.platform_icon_map[name]` as JSON
   - Extracts the `default` URL
   - Renders `<img src="{default_url}">` as a live preview thumbnail
   - The icon is **not stored** — it's derived from `name` at every read

### Query params

| Param | Type | Default | Description |
|---|---|---|---|
| `page` | int | 1 | 1-based page number |
| `pageSize` | int | 25 | Items per page |
| `search` | string | — | Global search across `name`, `link` |
| `sortBy` | string | `display_order` | Sort column |
| `sortOrder` | string | `asc` | `asc` or `desc` |
| `field` | string | — | Filter column name |
| `value` | string | — | Filter value |

---

## 2. Admin CRUD Endpoints

All require `Cookie: JSESSIONID=<admin_session>` (ADMIN role).

### Get single record

```
GET /api/v1/data/SOC/{uuid}
```

Returns full row as key/value map. No icon column.

### Create

```
POST /api/v1/data/SOC
Content-Type: application/json

{
  "name": "X",
  "link": "https://x.com/username",
  "category": "SOCIAL",
  "display_order": 0,
  "is_active": true
}
```

> No `icon` field needed — the icon URL is resolved from the platform catalog
> based on the `name` at read time.
>
> Response: `{ "id": "uuid-..." }`

### Update

```
PUT /api/v1/data/SOC/{uuid}
Content-Type: application/json

{
  "link": "https://x.com/new-profile",
  "display_order": 1
}
```

Response: `{ "updated": true }`

### Delete

```
DELETE /api/v1/data/SOC/{uuid}
```

Response: `{ "deleted": true }`

---

## 3. Public Read API

### All content (single call)

```
GET /api/content?type=socials
```

No auth required (PUBLIC).

Response:
```json
{
  "socials": [
    {
      "id": "a1b2c3d4-...",
      "name": "X",
      "link": "https://x.com/username",
      "iconUrl": "https://cdn.simpleicons.org/x",
      "displayOrder": 0,
      "category": "SOCIAL"
    }
  ],
  "count": 1
}
```

The public API resolves the icon URL from the platform catalog based on the
`name` field and returns it as a string in `iconUrl`.

### Get all types at once

```
GET /api/content
```

Returns `socials`, `portfolio`, `blogs`, `books`, `feature_flags` in a single response.

### List available types

```
GET /api/content/types
```

### Query params

| Param | Description |
|---|---|
| `?type=socials,portfolio` | Return only specified types (omit for all) |
| `?socials_limit=N` | Limit socials returned |
| `?portfolio_limit=N` | Limit portfolio projects |
| `?blogs_limit=N` | Limit blog posts |
| `?books_limit=N` | Limit books returned |
| `?feature_category=X` | Feature flag category (default: `PORTFOLIO`) |

---

## 4. Icon Resolution

### From the catalog

Each platform in `catalog.yaml` has icon variant slugs. The backend resolves URLs
using the simpleicons CDN:

```
https://cdn.simpleicons.org/{slug}
```

This serves an **SVG** by default. Append `?format=png` for PNG:

```
https://cdn.simpleicons.org/{slug}?format=png
```

### Icon JSON format (in `platform_icon_map` metadata)

```json
{
  "default": "https://cdn.simpleicons.org/github",
  "style": "line",
  "line": "github",
  "monochrome": "github",
  "normal": "github",
  "filled": "github"
}
```

| Key | Required | Description |
|---|---|---|
| `default` | **yes** | Primary icon URL (SVG). Always present. |
| `style` | no | Default/preferred style |
| `line` | no | Simpleicons slug for line/outline variant |
| `monochrome` | no | Simpleicons slug for grayscale variant |
| `normal` | no | Simpleicons slug for normal variant |
| `filled` | no | Simpleicons slug for filled/solid variant |

### Platform → Icon URL mapping

| Platform Code | default URL |
|---|---|
| GITHUB | `https://cdn.simpleicons.org/github` |
| X | `https://cdn.simpleicons.org/x` |
| LINKEDIN | `https://cdn.simpleicons.org/linkedin` |
| INSTAGRAM | `https://cdn.simpleicons.org/instagram` |
| EMAIL | `https://cdn.simpleicons.org/maildotru` |
| YOUTUBE | `https://cdn.simpleicons.org/youtube` |
| MASTODON | `https://cdn.simpleicons.org/mastodon` |
| DISCORD | `https://cdn.simpleicons.org/discord` |
| OTHER | `https://cdn.simpleicons.org/link` |

### Rendering

```html
<!-- Public footer: use iconUrl from the public API -->
<img
  src={social.iconUrl}
  alt={social.name}
  class="social-icon"
  width="24"
  height="24"
/>

<!-- Admin preview: parse platform_icon_map JSON -->
<img
  src={JSON.parse(metadata.platform_icon_map[name]).default}
  alt={name}
  class="social-icon-preview"
/>
```

---

## 5. Frontend Behavior Checklist

1. **Two-step selection**: Show `category` dropdown first (SOCIAL, CODING_PROFILE),
   then `name` (platform) dropdown.
2. **Icon preview before create**: When `name` is selected, parse
   `metadata.platform_icon_map[name]` as JSON and extract the `default` URL.
   Render `<img src="{url}">` as a thumbnail preview.
3. **No icon storage**: Do not send `icon` in the POST/PUT body. The icon URL is
   derived from `name` at read time via the catalog.
4. **Public rendering**: Use `GET /api/content?type=socials` — response has `iconUrl`
   (string). Render directly as `<img src={iconUrl} />`.
5. **`withCredentials: true`** required for all admin endpoints.
