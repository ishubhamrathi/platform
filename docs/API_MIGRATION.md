# Content API — Migration Guide

## Overview

The content API is consolidated from multiple endpoints into a **single endpoint**. This guide shows clients what changed.

> **Authentication required:** This endpoint is no longer public. Clients must include a valid `X-API-Key` header (project API key) in requests.

---

### Before (Legacy)

| Method | Old Endpoint | Served By |
|---|---|---|
| `GET` | `/api/socials` | `SocialsController` (never deployed — removed before release) |
| `GET` | `/api/portfolio/projects` | `PortfolioController` → `PortfolioPublicService` |
| `GET` | `/api/blog/posts` | `BlogController` → `BlogPublicService` |
| `GET` | `/api/features?category=portfolio` | `FeatureFlagController` → `FeatureFlagService` |

Clients had to make **up to 4 separate API calls** to load footer socials + portfolio projects + blog summaries + feature flags.

**Admin (unchanged):**
| Method | Endpoint |
|---|---|
| `GET` | `/api/v1/widget/{entityCode}` |
| `POST/PUT/DELETE` | `/api/v1/data/{entityCode}/...` |

---

### After (Consolidated)

| Method | New Endpoint |
|---|---|
| `GET` | `/api/content` |
| `GET` | `/api/content/types` |

**One call** returns all site content. Optional params to filter:

| Param | Description |
|---|---|
| `?type=socials,portfolio` | Comma-separated list — return only specified types (omit for **all**) |
| `?socials_limit=N` | Cap number of social links returned (max 100) |
| `&portfolio_limit=N` | Cap portfolio projects (max 100) |
| `?blogs_limit=N` | Cap blog post summaries (max 100) |
| `?books_limit=N` | Cap books returned (max 100) |
| `?feature_category=X` | Feature flag category (default: `PORTFOLIO`; categories are uppercase) |

---

## Response Format

### `GET /api/content` (all types)

```json
{
  "socials": {
    "socials": [
      {
        "id": "a1b2c3d4-...",
        "name": "GITHUB",
        "link": "https://github.com/username",
        "iconUrl": "https://cdn.simpleicons.org/github",
        "displayOrder": 0,
        "category": "SOCIAL"
      }
    ],
    "count": 3
  },
  "portfolio": {
    "projects": {
      "title": "Projects",
      "items": [
        {
          "id": "uuid-...",
          "title": "My Project",
          "shortDescription": "...",
          "description": "..."
        }
      ]
    }
  },
  "blogs": {
    "posts": [
      {
        "id": "uuid-...",
        "title": "Post Title",
        "tags": ["react", "tailwind-css"],
        "visibilityStatus": "SHOW",
        "excerpt": "..."
      }
    ],
    "count": 5
  },
  "books": {
    "books": [
      {
        "id": "uuid-...",
        "title": "Book Title",
        "author": "Author Name",
        "coverUrl": "https://...",
        "isFeatured": false,
        "displayOrder": 0
      }
    ],
    "count": 7
  },
  "feature_flags": {
    "category": "PORTFOLIO",
    "flags": {
      "show_portfolio": { "enabled": true }
    },
    "categories": ["ADMIN", "PORTFOLIO"]
  }
}
```

### `GET /api/content/types`

```json
{
  "types": ["socials", "portfolio", "blogs", "books", "feature_flags"],
  "count": 5
}
```

### `GET /api/content?type=socials`

```json
{
  "socials": {
    "socials": [...],
    "count": 3
  }
}
```

---

## Migration Steps for Clients

1. **Replace** calls to `/api/portfolio/projects`, `/api/blog/posts`, `/api/features` with a single call to `/api/content`.
2. **Access data** via the type key in the response (e.g. `response.socials.socials`, `response.portfolio.projects.items`, `response.books.books`).
3. **Optional:** pass `?type=...` if you only need certain content types.
4. **Social icons:** use the `iconUrl` string on each social (resolved from `catalog.yaml`); icons are not stored in the DB.
5. **Feature flag categories** are uppercase (e.g. `PORTFOLIO`, `ADMIN`). Passing a lowercase value is normalized server-side.
 6. **Authentication:** `/api/content` requires a valid `X-API-Key` header. Obtain a project API key from the admin panel (`/api/admin/clients/{projectKey}/api-keys`).

---

## Adding New Content Types

New content types can be added server-side by creating a Spring `@Component` that implements `PublicContentProvider`. No client-side change is needed — the new type automatically appears in `/api/content` and `/api/content/types` responses.

```java
@Component
public class TestimonialsContentProvider implements PublicContentProvider {
    @Override public String type() { return "testimonials"; }
    @Override public Map<String, Object> fetch(Map<String, String> params) { ... }
}
```
