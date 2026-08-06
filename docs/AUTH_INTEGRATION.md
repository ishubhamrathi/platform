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
- The backend uses **Spring Session** with a JDBC store (`spring.session.store-type: jdbc`, timeout 86400s). After login, the server sets the `SESSION` cookie automatically. The browser must send this cookie on subsequent requests (`credentials: "include"`).
- One active session per user (`maximumSessions(1)`). Login rotates the session id (old session is invalidated) to prevent session fixation.

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
2. **Protected routes:** Call `GET /api/auth/me` on app load to check if the user is still authenticated.
3. **Logout:** Call `POST /api/auth/logout`, then clear any local auth state and redirect to login.
4. **Password storage:** Passwords are stored using BCrypt encoding via `PasswordEncoder`.

### Example fetch calls (JavaScript)

```javascript
// Login
const res = await fetch('http://localhost:8080/api/auth/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  credentials: 'include',
  body: JSON.stringify({ email: 'admin@example.com', password: 'password' })
});
const data = await res.json();

// Check auth
const meRes = await fetch('http://localhost:8080/api/auth/me', {
  credentials: 'include'
});
const user = await meRes.json();

// Logout
await fetch('http://localhost:8080/api/auth/logout', {
  method: 'POST',
  credentials: 'include'
});
```
