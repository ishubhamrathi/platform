# API Access Control — Frontend Integration Guide

## Overview

The `/api/content` endpoint is no longer public. All requests must include a valid project API key in the `X-API-Key` header. This document describes the API contract changes and how frontend clients should authenticate and manage access rules.

---

## API Contract Changes

### Changed: `GET /api/content`

| Aspect | Before | After |
|---|---|---|
| Authentication | None (public) | Requires `X-API-Key` header |
| Access | Any client | Only clients with a matching PROJECT access rule |
| Response | Same structure | Same structure (no change) |

**Request:**
```
GET /api/content
X-API-Key: pk_<prefix>_<secret>
```

**Response:** Same as before — consolidated content (socials, portfolio, blogs, books, feature flags).

**Error responses:**
| Status | Meaning |
|---|---|
| `401` | Missing or invalid `X-API-Key` header |
| `403` | Authenticated but no access rule for this path |

### Changed: `GET /api/content/types`

Same authentication requirements as `GET /api/content`.

---

## New: API Key Management

### Generate API Key with Access Rules

Create a project API key and pre-scope its access rules in a single call.

**Request:**
```
POST /api/admin/clients/{projectKey}/api-keys
Content-Type: application/json
Cookie: JSESSIONID={admin_session}

{
  "name": "frontend-content-key",
  "rules": [
    {
      "name": "Content API read access",
      "pathPattern": "/api/content/**",
      "matchType": "ANT",
      "accessLevel": "PROJECT",
      "httpMethods": "GET"
    }
  ]
}
```

**Response** (`201 Created`):
```json
{
  "id": "uuid...",
  "projectKey": "my-app",
  "prefix": "a1b2c3",
  "name": "frontend-content-key",
  "apiKey": "pk_a1b2c3_x7f9k2m...",
  "rules": 1
}
```

> **Warning:** The `apiKey` field is returned **once** at creation time. Store it securely. It cannot be retrieved again.

**Without rules** (backward compatible):
```json
{
  "name": "my-key"
}
```
Omitting `rules` creates a key with no scoped rules — the key authenticates but won't match any PROJECT-level path rules unless explicit rules are added later via the Access Control UI.

### Rotate API Key Secret

Generate a new secret for an existing key. The old secret is immediately invalidated; the new secret is returned once.

```
POST /api/admin/clients/{projectKey}/api-keys/{keyId}/rotate
Cookie: JSESSIONID={admin_session}
```

**Response** (`200 OK`):
```json
{
  "id": "uuid...",
  "projectKey": "my-app",
  "prefix": "a1b2c3",
  "name": "frontend-content-key",
  "apiKey": "pk_a1b2c3_newSecret..."
}
```

> **Warning:** The new `apiKey` is returned **once**. Store it securely. The old secret stops working immediately.

### Revoke API Key

```
DELETE /api/admin/clients/{projectKey}/api-keys/{keyId}
Cookie: JSESSIONID={admin_session}
```

---

## Access Control Configuration (Dropdown Values)

The following endpoints provide enum values for the Access Control UI dropdowns.

### Access Levels

```
GET /api/admin/config/access-levels
```

```json
{
  "levels": [
    { "value": "PROJECT", "label": "Project API Key" },
    { "value": "ADMIN", "label": "Admin Session" }
  ]
}
```

### Match Types

```
GET /api/admin/config/match-types
```

```json
{
  "types": [
    { "value": "ANT", "label": "Ant Path (e.g. /api/content/**)" },
    { "value": "REGEX", "label": "Regular Expression" }
  ]
}
```

### HTTP Methods

```
GET /api/admin/config/http-methods
```

```json
{
  "methods": [
    { "value": "GET", "label": "GET" },
    { "value": "POST", "label": "POST" },
    { "value": "PUT", "label": "PUT" },
    { "value": "DELETE", "label": "DELETE" },
    { "value": "PATCH", "label": "PATCH" },
    { "value": "HEAD", "label": "HEAD" },
    { "value": "OPTIONS", "label": "OPTIONS" },
    { "value": "", "label": "Any (no restriction)" }
  ]
}
```

### Entity Paths

```
GET /api/admin/config/entity-paths
```

```json
{
  "entities": [
    { "code": "SOC", "table": "socials", "label": "SOC (socials)" },
    { "code": "PFP", "table": "portfolio_projects", "label": "PFP (portfolio_projects)" },
    { "code": "BLG", "table": "blog_posts", "label": "BLG (blog_posts)" },
    { "code": "BKS", "table": "books", "label": "BKS (books)" },
    { "code": "FTF", "table": "feature_flags", "label": "FTF (feature_flags)" },
    ...
  ]
}
```

---

## Access Rule Configuration

When creating or editing an access rule, the following fields are available:

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | Yes | Human-readable rule name |
| `pathPattern` | string | Yes | URL path pattern (ANT or REGEX depending on `matchType`) |
| `matchType` | string | Yes | `ANT` or `REGEX` |
| `accessLevel` | string | Yes | `PROJECT` or `ADMIN` |
| `httpMethods` | string | No | Comma-separated HTTP methods (e.g. `GET,POST`). Empty means any method. |

### ANT Path Patterns

ANT patterns use Spring's `AntPathMatcher`:
- `/api/content/**` — matches `/api/content` and all sub-paths
- `/api/content` — matches exactly `/api/content`
- `/api/**` — matches any path under `/api`

### REGEX Path Patterns

REGEX patterns use Java's `Pattern.matches()` (full match, not partial):
- `/api/content` — matches exactly `/api/content`
- `/api/content\?type=.*` — matches `/api/content` with any query string
- `/api/(content|health)` — matches `/api/content` or `/api/health`

### Project Key Scoping

When a rule has a non-null `project_key`, only API keys belonging to that project can match it. Rules with `project_key = null` match any project key (backward compatible).

---

## Caching

API access rules are cached in memory for performance:

- **Default TTL:** 60 minutes (`api-access.rules-cache-ttl-minutes` in `api-access.yaml`)
- **Immediate invalidation:** Cache is cleared when rules are created/updated/deleted via the admin UI or `/api/v1/data/ACR` endpoints
- **On TTL expiry:** Rules are automatically reloaded from the database on the next request

---

## Migration Checklist for Frontend Clients

1. **Generate an API key** via `POST /api/admin/clients/{projectKey}/api-keys` with a content API access rule
2. **Store the `apiKey`** securely (never commit to source control)
3. **Add `X-API-Key` header** to all `/api/content/**` requests
4. **Handle 401/403 responses** gracefully (show auth error or redirect to admin)
5. **Rotate keys periodically** — revoke old keys and generate new ones via the admin panel

### Example Frontend Integration

```javascript
// Fetch content with API key
const response = await fetch('/api/content?type=socials,portfolio', {
  headers: {
    'X-API-Key': 'pk_a1b2c3_x7f9k2m...',
    'Content-Type': 'application/json'
  },
  credentials: 'include'
});

if (response.status === 401) {
  // API key missing or invalid — redirect to admin to generate one
  window.location.href = '/admin/api-keys';
} else if (response.status === 403) {
  // Authenticated but no access — key doesn't have content API rule
  showError('Access denied. Please contact the administrator.');
}

const data = await response.json();
```
