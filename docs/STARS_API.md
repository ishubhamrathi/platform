# Stars API — "Leave Your Light"

Visitor-generated, shared star field for the portfolio `#light` section. Every
visitor may place **one permanent star** in the sky. This endpoint is **optional**
on the client: if it fails or is not implemented yet, the section renders an
offline state and must never take down the rest of the site.

Base URL: `VITE_API_BASE` (default `http://localhost:8080`). CORS allows the
portfolio origin (same policy as `/api/content` and `/api/contact`).

## Authentication

`/api/stars` is a **client-access API** (admin by default). Every request must
present the client's API key secret:

```
X-API-Key: <client-secret>
```

The secret is issued in the **Access Control** console (Admin → Access Control →
Clients): create a client, generate its API key, then add a per-client rule for
`/api/stars` (path pattern `/api/stars`, methods `GET,POST`). Requests without a
valid key are rejected with `403 Forbidden`. The key must be kept server-side in
the consumer project's deployment environment — never expose it to browsers or
the public bundle.

## Endpoints

| Method | Endpoint       | Description                                   |
|--------|----------------|-----------------------------------------------|
| `GET`  | `/api/stars`   | Current night sky + aggregate counters        |
| `POST` | `/api/stars`   | Place one permanent anonymous star            |

---

## `GET /api/stars`

Returns the full night sky (newest first) plus aggregate counters.

**Response `200 OK`**

```json
{
  "stars": [
    {
      "id": "star_01J9Y3…",
      "name": "AI Explorer",
      "city": "Faridabad",
      "country": "India",
      "color": "#fff8e1",
      "added_at": "2026-08-11T14:22:00Z"
    }
  ],
  "meta": {
    "total_stars": 1284,
    "cities": 412,
    "countries": 68,
    "visitor_has_star": false
  }
}
```

**Field notes**

- `stars` — newest first. May be capped at ~10 000 rows; `meta` totals are
  always exact.
- `id` — stable string (`star_` + ULID). Used by the frontend as a seeded
  position hash, so positions are deterministic per id across requests.
- `name`, `city`, `country` — optional strings; `""` when empty.
- `color` — one of the client palette hex values (see below), always present.
- `added_at` — ISO 8601 UTC timestamp (render as e.g. "Aug 2026").
- `meta.cities` / `meta.countries` — **distinct** non-empty values.
- `meta.visitor_has_star` — whether **this** visitor already contributed
  (drives the "one star per visitor" UI). The backend identifies the visitor by
  IP + a short-lived `star_visitor` cookie. The frontend also blocks a second
  submit locally after a successful POST.

**Cookies**

The backend issues a `star_visitor` cookie (HttpOnly, 30-day, `SameSite=Lax`)
when absent. On subsequent requests the cookie is the primary visitor identity;
the IP is a secondary check.

---

## `POST /api/stars`

Creates a new anonymous star.

**Request body** — all fields optional

```json
{
  "name": "AI Explorer",
  "city": "Faridabad",
  "country": "India",
  "color": "#fff8e1"
}
```

**Response `201 Created`**

```json
{
  "star": {
    "id": "star_01J9Y3…",
    "name": "AI Explorer",
    "city": "Faridabad",
    "country": "India",
    "color": "#fff8e1",
    "added_at": "2026-08-13T09:10:00Z"
  },
  "meta": {
    "total_stars": 1285,
    "cities": 413,
    "countries": 68
  }
}
```

**Response `409 Conflict`** — this visitor already placed a star

```json
{ "error": "You have already placed a star in this sky.", "hint": null }
```

**Response `400 Bad Request`** — a field exceeds its maximum length

```json
{ "error": "name must be at most 120 characters", "hint": null }
```

**Response `429 Too Many Requests`** — rate limit exceeded (5 POSTs / min / IP)

```json
{ "error": "Too many requests. Please try again shortly.", "hint": null }
```

**Field limits & clamping**

| Field     | Max length |
|-----------|-----------:|
| `name`    | 120        |
| `city`    | 120        |
| `country` | 120        |
| `color`   | —          |

- Empty strings are stored as empty / omitted.
- `color` is clamped to the nearest palette value; anything that is not a valid
  `#rrggbb` hex falls back to `#fff8e1` (warm white).

---

## Visitor identity (one star per visitor)

- Identified by the **short-lived `star_visitor` cookie** (HttpOnly, 30 days,
  `SameSite=Lax`) issued by the backend on first request. The cookie is the only
  identity used for the one-star-per-visitor rule.
- Raw IPs are **never stored or exposed** — only a SHA-256 hash is persisted
  (nullable, used for per-IP rate limiting and optional geolocation; it does not
  deduplicate visitors).
- A second `POST` carrying the same `star_visitor` cookie returns `409`.
- Loopback IPs (local dev) are not IP-tracked, so multiple local browsers can
  each place a star.

## Star color palette

The frontend exposes exactly these swatches (calm, non-neon). The backend clamps
out-of-palette colors to the nearest listed value.

| Hex       | Tone        |
|-----------|-------------|
| `#fff8e1` | warm white  |
| `#ffd9a8` | peach       |
| `#fde68a` | gold        |
| `#fbcfe8` | rose        |
| `#c4b5fd` | violet      |
| `#c7d2fe` | periwinkle  |
| `#a7f3d0` | mint        |

---

## Client behavior on failure

- **`GET /api/stars` failure** → section shows "The sky is quiet right now.
  Try again soon." and the add controls are disabled. Details are logged to the
  console only.
- **`POST /api/stars` failure** → form shows generic copy ("Your star couldn't
  take off. Try again."). Never show raw status codes or URLs.

## Critical rules

- Authentication required via `X-API-Key` (client secret from the Access Control
  console); without a valid key the endpoint returns `403`. This is not a
  per-visitor auth — the visitor identity (cookie/IP) still determines
  `meta.visitor_has_star` and the one-star-per-visitor rule.
- All responses are JSON (`Content-Type: application/json`).
- Geolocation is best-effort: the client sends `city` / `country` hints from
  `https://ipapi.co/json/`; the backend prefers its own server-side lookup when
  enabled (`STARS_IPGEO_ENABLED=true`) and otherwise trusts the client hints.
- Persistence is permanent (database row). The endpoint must never take down the
  rest of the site if it fails.
