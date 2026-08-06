# Blog Tags & Icon Suggestions API

## Overview

Blog posts (`BLG` → `blog_posts`) use a free-text **tags** system instead of
fixed top-level/sub categories. Tags are stored as a JSONB string array on the
`tags` column and rendered as simpleicons icons in the admin UI.

The backend does **not** maintain a hardcoded tag catalog — tags are whatever the
author enters. The suggestions endpoint returns existing tags already used in the
DB, and the frontend can preview icons for new tags by constructing the
simpleicons URL from the tag code.

---

## Tag Suggestions Endpoint

### `GET /api/v1/blog/tags/suggestions?q={query}&limit={n}`

Admin-only (ADMIN role required). Search existing tags across all blog posts
(case-insensitive partial match). Each result includes a pre-resolved simpleicons
icon URL.

#### Query params

| Param | Type | Default | Description |
|---|---|---|---|
| `q` | string | (empty) | Search term to filter tags |
| `limit` | int | 20 | Max results (1–500) |

#### Response

```json
{
  "tags": [
    {
      "value": "tailwind-css",
      "label": "Tailwind Css",
      "icon": "https://cdn.simpleicons.org/tailwind-css"
    },
    {
      "value": "react",
      "label": "React",
      "icon": "https://cdn.simpleicons.org/react"
    }
  ],
  "count": 2,
  "totalExisting": 18,
  "simpleiconsBaseUrl": "https://cdn.simpleicons.org/"
}
```

---

## Frontend Behavior

### 1. Live icon search as-you-type

When the user types in the tags field:

1. Call `GET /api/v1/blog/tags/suggestions?q={typedText}` (debounce 300ms)
2. Display matching results as selectable options with icon previews
3. Each option's `icon` field is a direct image URL — render `<img src="{icon}">`

### 2. Adding new tags (allowNew)

- The widget column has `allowNew: true`, so the user can type any value not in
  the suggestions list
- For new tags, construct the icon URL the same way the backend does:
  `https://cdn.simpleicons.org/{tagCode}`
- Example: typing `kotlin` → icon URL `https://cdn.simpleicons.org/kotlin`
- The simpleicons CDN returns an SVG for valid slugs and a 404/error fallback
  for unknown ones — the frontend can hide/show a placeholder accordingly

### 3. Widget metadata

The BDUI widget (`/api/v1/widget/BLG`) returns metadata with:

```json
{
  "tagSuggestionsEndpoint": "/api/v1/blog/tags/suggestions",
  "simpleiconsBaseUrl": "https://cdn.simpleicons.org/",
  "catalog": {
    "blogTags": [ ... existing tags with icon URLs ... ]
  }
}
```

Use `tagSuggestionsEndpoint` for live search; `catalog.blogTags` provides the
initial dropdown options (existing tags with icons).

### 4. Submitting tags

Tags are submitted as a JSON array of strings in the `tags` field:

```json
POST /api/v1/data/BLG
{
  "title": "My Post",
  "content": "<p>...</p>",
  "tags": ["react", "tailwind-css", "spring-boot"],
  "is_published": true
}
```

The backend stores the array as JSONB. `author` and `published_at` are set
automatically by the server.

---

## Summary of tag behavior

| Aspect | Detail |
|---|---|
| Storage | `tags JSONB DEFAULT '[]'` on `blog_posts` |
| Input type | Free-text multiselect with `allowNew: true` |
| Icon source | simpleicons CDN (`https://cdn.simpleicons.org/{code}`) |
| Search | `GET /api/v1/blog/tags/suggestions?q=...` (existing DB tags) |
| New tags | Frontend constructs icon URL from tag code; no backend config needed |
| Public response | `tags` array of strings in `/api/content?type=blogs` |
