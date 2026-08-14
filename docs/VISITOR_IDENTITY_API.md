# Visitor Identity API

Reusable anonymous identity system. Maps a cookie to a persistent random
username (e.g., `WittyFox42`). No signup required. Works across features
(lounge, stars, etc.).

Base URL: `VITE_API_BASE` (default `http://localhost:8080`).

## Authentication

This is a **public endpoint** — no `X-API-Key` required. Identity is scoped
by the optional `X-Project-Key` header.

## Endpoints

| Method   | Endpoint        | Description                                   |
|----------|-----------------|-----------------------------------------------|
| `POST`   | `/api/identity` | Get or create anonymous visitor identity      |
| `GET`    | `/api/identity` | Retrieve current identity (read-only)         |

---

## `POST /api/identity`

Get or create an identity for this visitor. If no `visitor_identity` cookie
exists, one is issued with a 1-year expiry.

**Headers**

| Header          | Required | Description                      |
|-----------------|----------|----------------------------------|
| `X-Project-Key` | no       | Project scope (e.g., `portfolio`)|

**Response `200 OK`**

```json
{
  "identity_id": "550e8400-e29b-41d4-a716-446655440000",
  "username": "WittyFox42",
  "created_at": "2026-08-14T14:30:00Z",
  "last_seen_at": "2026-08-14T14:30:00Z"
}
```

**Cookie issued**

| Cookie             | HttpOnly | Max Age | SameSite | Path |
|--------------------|----------|---------|----------|------|
| `visitor_identity` | yes      | 365 days| Lax      | `/`  |

---

## `GET /api/identity`

Retrieve an existing identity without creating one. Returns `204 No Content`
if no cookie is present or the identity doesn't exist.

**Cookie required**: `visitor_identity`

**Response `200 OK`**

```json
{
  "identity_id": "550e8400-e29b-41d4-a716-446655440000",
  "username": "WittyFox42",
  "created_at": "2026-08-14T14:30:00Z",
  "last_seen_at": "2026-08-14T15:00:00Z"
}
```

**Response `204 No Content`** — no identity found

---

## Frontend Integration

### First visit (no cookie)

```javascript
// POST /api/identity — triggers cookie set + identity creation
const res = await fetch(`${API_BASE}/api/identity`, {
  method: 'POST',
  credentials: 'include',  // important: send/receive cookies
  headers: { 'X-Project-Key': 'portfolio' }
});
const { identity_id, username } = await res.json();
// Cache in localStorage for quick access
localStorage.setItem('visitor_username', username);
localStorage.setItem('visitor_identity_id', identity_id);
```

### Subsequent visits (cookie exists)

```javascript
// GET /api/identity — retrieve existing identity
const res = await fetch(`${API_BASE}/api/identity`, {
  credentials: 'include'
});
if (res.ok) {
  const { username } = await res.json();
  localStorage.setItem('visitor_username', username);
}
```

### Quick local access (no network)

```javascript
// Read from localStorage first (fast path)
const username = localStorage.getItem('visitor_username');
if (username) {
  displayUsername(username);
} else {
  // Fallback: call POST /api/identity
}
```

## Username Format

Random `Adjective + Noun + Number` pattern:

| Example        | Pool size |
|----------------|-----------|
| `WittyFox42`   | 50 adjectives × 50 nouns × 999 numbers = ~2.5M unique |

Adjectives: Witty, Calm, Bright, Bold, Gentle, Swift, Keen, Merry, Noble, Proud,
Brave, Cool, Deep, Fair, Glad, Jade, Luna, Neon, Opal, Sage, Azure, Coral, Ember,
Fern, Grace, Haven, Ivory, Jasper, Lark, Maple, Pearl, Snow, Wren, Ash, Bay,
Cedar, Dawn ...

Nouns: Fox, Bear, Owl, Wolf, Hawk, Lynx, Deer, Puma, Crane, Raven, Lion, Panda,
Tiger, Eagle, Falcon, Heron, Jaguar, Koala, Leopard, Moose, Otter, Penguin, Quail,
Robin, Tern, Viper, Whale, Yak, Zebra, Ant, Bee, Bug, Clam, Duck, Eel, Frog,
Gull, Hare, Mite, Newt, Pike, Ray, Toad, Crab, Snail, Wasp ...

## Identity Lifecycle

| Event | What happens |
|-------|--------------|
| **First visit** (no cookie) | New cookie issued, new username generated |
| **Return visit** (cookie exists) | `last_seen_at` updated |
| **Cookie cleared** (browser data wipe) | New identity created on next visit — old username orphaned |
| **Incognito/private mode** | New identity per session — cookie discarded on close |
| **Switches device/browser** | New identity — no cross-device linking |
| **Cookie expiry** (365 days) | Browser discards cookie, next visit creates new identity |

**Key points:**
- Identity is **cookie-bound** — clearing cookies = new identity
- **No cross-device** linking — each device/browser gets its own identity
- Old identities are **never deleted** — they remain in the database

## Critical Rules

- **Cookie is HttpOnly** — JavaScript cannot read it directly. Use
  `localStorage` as a fast cache for the username.
- **Identity is permanent** — once created, the same cookie always returns
  the same username.
- **No auth required** — this is a public endpoint. The cookie alone is the
  identity.
- **Project scoping** — the optional `X-Project-Key` header allows different
  identity pools per project feature.
