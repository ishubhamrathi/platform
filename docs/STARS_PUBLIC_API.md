# Stars Public API

## Overview

Public read-only endpoint for the "Leave Your Light" star field. No authentication required.

---

## 1. List Stars

### Endpoint
```
GET /api/content?type=stars
```

### Response (200 OK)
```json
{
  "stars": {
    "meta": {
      "total_stars": 4,
      "cities": 0,
      "countries": 0,
      "visitor_has_star": false
    },
    "stars": [
      {
        "id": "star_06GEF92FGS53RZGVPMYT9R6VP3",
        "name": "Aurora",
        "city": "",
        "country": "",
        "color": "#a7f3d0",
        "added_at": "2026-09-28T10:51:40.294684Z",
        "username": ""
      }
    ]
  }
}
```

### Response Fields

#### Star Object
| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Stable ID (`star_` + ULID) |
| `name` | string | Visitor's name (may be empty) |
| `city` | string | City (may be empty) |
| `country` | string | Country (may be empty) |
| `color` | string | Hex color from palette |
| `added_at` | ISO 8601 | Timestamp when star was placed |
| `username` | string | Random username (e.g. "BraveFox42") |

#### Meta Object
| Field | Type | Description |
|-------|------|-------------|
| `total_stars` | integer | Total stars in sky |
| `cities` | integer | Distinct non-empty cities |
| `countries` | integer | Distinct non-empty countries |
| `visitor_has_star` | boolean | Whether current visitor has a star |

---

## 2. Star Color Palette

| Hex | Tone |
|-----|------|
| `#fff8e1` | warm white |
| `#ffd9a8` | peach |
| `#fde68a` | gold |
| `#fbcfe8` | rose |
| `#c4b5fd` | violet |
| `#c7d2fe` | periwinkle |
| `#a7f3d0` | mint |

---

## 3. Frontend Integration

```js
async function fetchStars() {
  const res = await fetch('/api/content?type=stars');
  if (!res.ok) throw new Error('Failed to fetch stars');
  return res.json();
}

const { stars, meta } = await fetchStars();
```

---

## 4. Notes

- **Public endpoint** — no `X-API-Key` or session required
- **Visitor identity** — uses `visitor_identity` cookie for `visitor_has_star`
- **Caching** — responses include `Cache-Control: public, max-age=300`