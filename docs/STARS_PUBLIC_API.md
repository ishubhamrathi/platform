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
        "username": "",
        "region": "",
        "country_code": "",
        "timezone": "",
        "latitude": null,
        "longitude": null
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
| `region` | string | State / province (may be empty) |
| `country_code` | string | ISO 3166-1 alpha-2, lowercase (may be empty) |
| `timezone` | string | IANA timezone id (may be empty) |
| `latitude` | number \| null | Approximate city-centroid latitude, or `null` |
| `longitude` | number \| null | Approximate city-centroid longitude, or `null` |

The location fields are best-effort IP geolocation. `region`, `country_code`,
`timezone`, `latitude` and `longitude` are all `""` or `null` for stars placed
before location resolution existed and for stars whose address could not be
resolved (loopback, private ranges, provider failure). `latitude` and
`longitude` are always either both set or both `null`, and are city-centroid
approximations accurate to a few kilometres — not a device-level fix. Treat them
as optional in all consumers.

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