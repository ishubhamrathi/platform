# Backend Auth API Integration Guide

## Base URL
```
http://localhost:8080/api/auth
```

## Session Cookie
- **Cookie name:** `SESSION`
- **Path:** `/`
- **Max-Age:** 86400 seconds (1 day)
- **SameSite:** `None`
- **Secure:** `true` — the cookie is only sent over HTTPS (`http://localhost` is treated as a secure context by browsers). Do not change these flags in the browser.
- The backend uses **Spring Session** with a JDBC store (`spring.session.store-type: jdbc`, timeout 86400s). The `SPRING_SESSION` / `SPRING_SESSION_ATTRIBUTES` tables are created by Flyway migration **V87** in the `platform` schema (`spring.session.jdbc.initialize-schema: never` — schema is Flyway-owned, so the store must not create or drop it). After login, the server sets the `SESSION` cookie automatically. The browser must send this cookie on subsequent requests (`credentials: "include"`).
- One active session per user (`maximumSessions(1)`). Login rotates the session id (old session is invalidated) to prevent session fixation.

---

## CSRF Protection (required)

CSRF is **enabled**. The server issues a `XSRF-TOKEN` cookie (not HttpOnly) and expects it back
in the `X-XSRF-TOKEN` **request header** on every state-changing request.

**Rules:**
- **Unsafe methods** — `POST`, `PUT`, `PATCH`, `DELETE` — MUST include the `X-XSRF-TOKEN` header.
- **Safe methods** — `GET`, `HEAD`, `OPTIONS` — do not need the header.
- Endpoints reached **before any session or CSRF cookie exists** are exempt:
  `/api/auth/login`, `/api/auth/register`, `/api/auth/logout`, `POST /api/identity`.
- A missing/invalid token returns **`403 Forbidden`** with `{"error":"Invalid CSRF token"}`.

The `XSRF-TOKEN` cookie is set automatically by the server, so a client only needs to read the
cookie and copy its value into the header. Refresh it after login.

**JavaScript helper (matches `frontend/src/api/client.ts`):**

```javascript
function getCookie(name) {
  const m = document.cookie.match(new RegExp('(?:^|;\\s*)' + name + '=([^;]*)'));
  return m ? decodeURIComponent(m[1]) : undefined;
}

const UNSAFE = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

async function apiFetch(path, options = {}) {
  const method = (options.method || 'GET').toUpperCase();
  const headers = { 'Content-Type': 'application/json', ...(options.headers || {}) };
  if (UNSAFE.has(method)) {
    const token = getCookie('XSRF-TOKEN');
    if (token) headers['X-XSRF-TOKEN'] = token;
  }
  return fetch(path, { ...options, headers, credentials: 'include' });
}
```

> `SameSite=None` cookies are sent on cross-site requests, which is why the header check
> (not the cookie alone) is what actually blocks CSRF. Do not remove the header logic.

---

## Authorization rules (current)

- **Public (no auth):** `/api/auth/register|login|logout|me`, `/api/health`,
  the `api-access.yaml` PUBLIC list, public reCALL `GET`s, and public read surfaces
  (`/api/content/**`, `/api/v1/explorer/**`, `/api/v1/blog/**`, `/api/identity/**`,
  `/api/stars/**`, `/api/assets/**` `GET`).
- **Any logged-in user:** notifications, timeline, `/api/recall/**` (non-public),
  `/api/auth/profile|metadata|level`, `/api/audit/**`.
- **ADMIN only:** `/api/admin/**`, `/api/v1/data/**`, `/api/v1/widget/**`.
  A project `X-API-Key` (`PROJECT` authority) is **never** sufficient for these.
- **Everything else** requires authentication — the chain is default-deny.

---

## 1. Register a new user
**Endpoint:** `POST /api/auth/register`

**Request body:**
```json
{
  "email": "admin@example.com",
  "password": "yourpassword",
  "name": "Admin Name"
}
```

**Success response (201 Created):**
```json
{
  "id": "3f2a1b7c-9d4e-4f6a-b8c1-0e2d3f4a5b6c",
  "email": "admin@example.com",
  "name": "Admin Name",
  "role": "USER"
}
```

**Error response (409 Conflict):**
```json
{
  "error": "Email already exists"
}
```

**Error response (400 Bad Request)** — request body fails validation
(`email` must be a valid email ≤ 255 chars, `password` ≥ 8 and ≤ 72 chars, `name` is required ≤ 255 chars):
```json
{
  "error": "Validation failed",
  "hint": "password size must be between 8 and 72"
}
```

---

## 2. Login
**Endpoint:** `POST /api/auth/login`

**Request body:**
```json
{
  "email": "admin@example.com",
  "password": "yourpassword"
}
```

**Success response (200 OK):**
```json
{
  "id": "3f2a1b7c-9d4e-4f6a-b8c1-0e2d3f4a5b6c",
  "email": "admin@example.com",
  "name": "Admin Name",
  "role": "USER"
}
```
*The server also sets the `SESSION` cookie in the response headers.*

**Error response (400 Bad Request)** — request body fails validation
(`email` must be a valid email ≤ 255 chars, `password` is required ≤ 72 chars):
```json
{
  "error": "Validation failed",
  "hint": "email must be a well-formed email address"
}
```

**Error responses for invalid credentials:**
- `401` `{ "error": "Invalid email or password" }` — wrong email/password (`CustomAuthenticationProvider` throws `BadCredentialsException`, mapped by `GlobalExceptionHandler`) or authentication succeeds but the user row is missing afterwards (rare race).

---

## 3. Get current user (check auth status)
**Endpoint:** `GET /api/auth/me`

**Headers:** Must include the `SESSION` cookie from login.

**Success response (200 OK):**
```json
{
  "id": "3f2a1b7c-9d4e-4f6a-b8c1-0e2d3f4a5b6c",
  "email": "admin@example.com",
  "name": "Admin Name",
  "role": "USER"
}
```

**Error response (401 Unauthorized):**
```json
{
  "error": "Not authenticated"
}
```
*Returned when no authenticated user (or session `USER_ID`) is found.*

---

## 4. Logout
**Endpoint:** `POST /api/auth/logout`

**Headers:** Must include the `SESSION` cookie.

**Success response (200 OK):**
```json
{
  "message": "Logged out successfully"
}
```
*The server invalidates the session. The browser should clear the `SESSION` cookie.*

---

## Frontend Implementation Notes

1. **Cookie handling:** Use `credentials: "include"` in fetch/axios requests so the browser sends/receives the `SESSION` cookie.
2. **CSRF header:** For `POST`/`PUT`/`PATCH`/`DELETE`, copy the `XSRF-TOKEN` cookie into the `X-XSRF-TOKEN` header (see the helper above). This is mandatory — these methods now fail with 403 without it.
3. **Protected routes:** Call `GET /api/auth/me` on app load to check if the user is still authenticated.
4. **Logout:** Call `POST /api/auth/logout`, then clear any local auth state and redirect to login.
5. **Password storage:** Passwords are stored using BCrypt encoding via `PasswordEncoder`.
6. **Admin surface:** `/api/admin/**` and `/api/v1/data|widget/**` now require a logged-in **ADMIN**. A `PROJECT` API key cannot call them.

### Example fetch calls (JavaScript)

```javascript
// Reuse the apiFetch() helper defined in the CSRF section above.

// Login (CSRF-exempt)
const res = await apiFetch('http://localhost:8080/api/auth/login', {
  method: 'POST',
  body: JSON.stringify({ email: 'admin@example.com', password: 'password' })
});
const data = await res.json();

// Check auth (safe method, no token needed)
const meRes = await apiFetch('http://localhost:8080/api/auth/me');
const user = await meRes.json();

// A state-changing call now carries X-XSRF-TOKEN automatically
await apiFetch('http://localhost:8080/api/auth/profile', {
  method: 'PUT',
  body: JSON.stringify({ name: 'New Name' })
});

// Logout (CSRF-exempt)
await apiFetch('http://localhost:8080/api/auth/logout', { method: 'POST' });
```
