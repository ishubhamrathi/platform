# Content Detail API — Generic Single-Item Endpoint

## Overview

Extends the consolidated `GET /api/content` list endpoint with a generic detail endpoint:

```
GET /api/content/{type}/{id}
```

Serves a **single published, visible, non-deleted** item with full fields (e.g. `content` for blogs). Designed for future types — adding a new `type` only requires backend `findById` wiring, no contract break.

- **Base path:** `/api/content/{type}/{id}`
- **Auth:** `X-API-Key: pk_<prefix>_<secret>` (same as `GET /api/content`, see `docs/API_ACCESS_CONTROL.md`). Needs PROJECT rule `pathPattern=/api/content/**`, `matchType=ANT`, `httpMethods=GET`.
- **Public list remains:** `GET /api/content?type=blogs&blogs_limit=N` returns summaries **without** `content` (see `docs/API_MIGRATION.md`). Use detail endpoint for full body.

---

## Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/content/blogs/{id}` | Blog post detail (alias `blog` also accepted) |
| `GET` | `/api/content/portfolio/{id}` | Portfolio project detail (alias `projects`) |
| `GET` | `/api/content/books/{id}` | Book detail (alias `book`) |
| `GET` | `/api/content/{type}/{id}` | Generic; unsupported `type` → `404` |

`{id}` must be a UUID string for `blogs`/`books`/`portfolio`. Invalid UUID → `404`.

---

## Authentication

```
GET /api/content/blogs/1a2b3c4d-...
X-API-Key: pk_a1b2c3_x7f9k2m...
```

Error responses:

| Status | Meaning |
|---|---|
| `401` | Missing/invalid `X-API-Key` |
| `403` | Key has no PROJECT rule for `/api/content/**` |
| `404` | Unknown `type`, malformed UUID, or item not found / not published / `visibility_status != SHOW` / soft-deleted |

---

## 1. Blog Detail — `GET /api/content/blogs/{id}`

### Controller

`ContentController.java:32` → `ContentControllerImpl.java:48` (`getByTypeAndId`) → `BlogPublicService.java:13`/`BlogPublicServiceImpl.java:26` → `BlogDao.java:14`/`BlogDaoImpl.java:62` (`findById`).

DAO filter: `is_published = true AND visibility_status = 'SHOW' AND deleted_at IS NULL`.

### Response `200 OK`

```json
{
  "id": "b1e2d3c4-...-...",
  "title": "Hello BlockNote",
  "tags": ["react", "spring-boot"],
  "visibilityStatus": "SHOW",
  "excerpt": "Short excerpt...",
  "author": "Shubham Rathi",
  "publishedAt": "2025-08-10T06:30:00",
  "createdAt": "2025-08-10T06:29:00",
  "updatedAt": "2025-08-11T09:12:00",
  "content": "<p>...</p> or BlockNote JSON array with {\"type\":\"image\",\"props\":{\"url\":\"https://...\"}}",
  "thumbnailUrl": "https://cdn.example.com/a/xyz.jpg"
}
```

| Field | Type | Notes |
|---|---|---|
| `id` | UUID string | `blog_post_id` |
| `title` | string |  |
| `tags` | `string[]` | parsed from `tags JSONB` via `BlogDaoImpl:108` |
| `visibilityStatus` | string | `SHOW` only |
| `excerpt` | string (richtext/HTML) |  |
| `author` | string | auto-filled from admin display name on create (`BduiDataServiceImpl.java:79`) |
| `publishedAt` | datetime | auto-set when `is_published=true` (`BduiDataServiceImpl.java:88,146`) |
| `content` | string | BlockNote JSON or HTML — **present only in detail**, not in `GET /api/content?type=blogs` list (`BlogDaoImpl:33` list query omits it) |
| `thumbnailUrl` | string \| null | see Thumbnail section |

### Thumbnail

- **Column:** `blog_posts.thumbnail_url VARCHAR(500)` — added in `V68__Add_Thumbnail_To_Blog_Posts.sql`. Comment: `Optional override; if null, derived from first image in content`.
- **Storage:** `BduiDataServiceImpl.java:90` (`create`) / `147` (`update`) — if `thumbnail_url` override is blank and `content` is present, `BlogThumbnailExtractor.java:1` (`common/blog/BlogThumbnailExtractor`) extracts first image via:
  1. JSON `"url": "https://..."` (BlockNote image blocks — primary)
  2. HTML `<img src="...">`
  3. Markdown `![](url)`
- **Read fallback:** `BlogDaoImpl.java:108` — `findById` derives thumbnail from `content` on-the-fly when stored column is null (handles older posts before backfill).
- **Admin override (upload):** `BlogWidgetService.java:67` exposes `thumbnail_url` as `type=image` (label `Thumbnail`). Rendered by reusable `frontend/src/components/admin/dynamic/ImageUploadField.tsx:1` — uses `api.uploadAsset` (`POST /api/assets/upload`, `AssetFileController.java:57`, field `file`) and returns `url` (`/a/{code}`) or `storageUrl`. See Reusable Upload section below.

**Examples:**

```
# Create with auto-derive (first image in content becomes thumbnail)
POST /api/v1/data/BLG
{
  "title": "Post",
  "content": "[{\"type\":\"image\",\"props\":{\"url\":\"https://cdn/a/1.jpg\"}}, ...]",
  "tags": ["react"]
}
# stored thumbnail_url = https://cdn/a/1.jpg

# Create with override
POST /api/v1/data/BLG
{
  "title": "Post",
  "content": "...",
  "thumbnail_url": "https://cdn/custom.jpg"
}
# stored thumbnail_url = https://cdn/custom.jpg (wins over extracted)

# Update: change content, no thumbnail_url sent → re-derives
PUT /api/v1/data/BLG/{id}
{ "content": "[{\"type\":\"image\",\"props\":{\"url\":\"https://cdn/a/2.jpg\"}}]" }

# Update: clear override → fallback to derived
PUT /api/v1/data/BLG/{id}
{ "thumbnail_url": "" }
```

---

## 2. Portfolio Detail — `GET /api/content/portfolio/{id}`

```
GET /api/content/portfolio/9f8a7b6c-...
X-API-Key: pk_...
```

→ `PortfolioPublicService.java:15`/`PortfolioPublicServiceImpl.java:42` → `PortfolioDao.java:15`/`PortfolioDaoImpl.java:57`.

Response shape (same as list items via `GET /api/content?type=portfolio`):

```json
{
  "id": "uuid-...",
  "title": "My Project",
  "shortDescription": "...",
  "description": "...",
  "image": "https://.../thumbnail.jpg",
  "carouselImages": ["https://.../1.jpg"],
  "tech": [{ "value": "react", "label": "React", "icon": "https://..." }],
  "github": "https://github.com/...",
  "deployed": "https://demo.example.com",
  "status": { "value": "COMPLETED", "label": "Completed" },
  "topCategory": { "value": "FULLSTACK", "label": "Full Stack" },
  "visibility": { "value": "SHOW", "label": "Show" },
  "createdAt": "...",
  "updatedAt": "..."
}
```

---

## 3. Books Detail — `GET /api/content/books/{id}`

```
GET /api/content/books/7e1a2c3d-...
X-API-Key: pk_...
```

→ `BooksPublicService.java:15`/`BooksPublicServiceImpl.java:26` → `BooksDao.java:13`/`BooksDaoImpl.java:55` (filter `is_active=true`).

Response (same as list, see `docs/BOOKS_API.md`):

```json
{
  "id": "uuid-...",
  "title": "Clean Code",
  "author": "Robert C. Martin",
  "description": "...",
  "coverUrl": "https://...",
  "genre": "Software Engineering",
  "googleLink": "https://books.google.com/...",
  "isFeatured": true,
  "displayOrder": 0,
  "createdAt": "...",
  "updatedAt": "..."
}
```

---

## Comparison: List vs Detail

| Use case | Endpoint | Returns `content`? | Returns `thumbnailUrl`? |
|---|---|---|---|
| Blog list/cards | `GET /api/content?type=blogs&blogs_limit=20` | **No** (`BlogDaoImpl:33` omits `content`) | Yes (stored `thumbnail_url`; null for unbackfilled old rows) |
| Blog detail page | `GET /api/content/blogs/{id}` | **Yes** | Yes (stored or derived via `BlogThumbnailExtractor`) |

Previously clients filtered blogs client-side from the list; now prefer detail endpoint for reading view.

---

## Frontend Integration

```js
// List (cards, no heavy body)
const listRes = await fetch('/api/content?type=blogs&blogs_limit=20', {
  headers: { 'X-API-Key': API_KEY }
});
const { blogs } = await listRes.json(); // blogs.posts[].thumbnailUrl

// Detail (reading view, full content + thumbnailUrl)
const detailRes = await fetch(`/api/content/blogs/${id}`, {
  headers: { 'X-API-Key': API_KEY }
});
if (detailRes.status === 404) showNotFound();
const post = await detailRes.json();
// post.content → render BlockNote/HTML
// post.thumbnailUrl → already server-derived (override or first image in content)
// <img src={post.thumbnailUrl} alt={post.title} />
```

**withCredentials:** Not needed for public reads (API key only). Admin CRUD still requires `credentials: 'include'` (`SESSION`).

---

## Adding Future Types

1. Add `findById` to the domain service/DAO (respect published/visibility checks).
2. Wire a `case "newtype":` branch in `ContentControllerImpl.java:48` (`getByTypeAndId`).
3. Ensure PROJECT rule `/api/content/**` already covers it — no client change needed.
4. Document new `type` in `ContentController.java:32` `allowableValues`.

Example from `docs/API_MIGRATION.md:156`:

```java
@Component
public class TestimonialsContentProvider implements PublicContentProvider {
    @Override public String type() { return "testimonials"; }
    @Override public Map<String, Object> fetch(Map<String, String> params) { ... }
}
// + add detail wiring: case "testimonials": item = testimonialsService.findById(id)
```

---

## Reusable Upload Component

`frontend/src/components/admin/dynamic/ImageUploadField.tsx:1` is a reusable field for any `type=image` column (blog `thumbnail_url`, future portfolio `thumbnail_image_url`, book `cover_url`, etc.).

- Props: `value` (URL string), `onChange(url)`, `disabled`, `uploadEndpoint` (defaults to `/api/assets/upload` from `AssetFileController.java:57`).
- Flow: `file` → `FormData` (`file`) → `api.uploadAsset()` (`frontend/src/api/client.ts:311` → `uploadFormData`) → `res.url` (`/a/{code}`) or `res.storageUrl` → `onChange(url)`.
- Wired in `frontend/src/components/admin/dashboard/ContentPanel.tsx:20` (`InlineField` checks `type === 'image'`), validation/payload treat `image` like `url` (`buildPayload` / `validateColumnValue`).
- Styles: `frontend/src/styles/admin.css` (`.v2-image-upload*`).

To reuse elsewhere, set column type to `image` in any `WidgetProvider`:

```java
Map.of("name", "cover_url", "label", "Cover", "type", "image", "sortable", false, "filterable", false)
```

---

## Files

- `backend/src/main/resources/db/migration/V68__Add_Thumbnail_To_Blog_Posts.sql`
- `backend/src/main/java/com/platform/common/blog/BlogThumbnailExtractor.java`
- `backend/src/main/java/com/platform/dao/impl/BlogDaoImpl.java` (typed `BLOG_POSTS.THUMBNAIL_URL`, single field `thumbnailUrl`)
- `backend/src/main/java/com/platform/service/bdui/impl/BduiDataServiceImpl.java` (auto-derive on `BLG` create/update)
- `backend/src/main/java/com/platform/widget/providers/BlogWidgetService.java` (`thumbnail_url` → `type=image`)
- `frontend/src/components/admin/dynamic/ImageUploadField.tsx` (reusable upload via `/api/assets/upload`)
- `frontend/src/components/admin/dashboard/ContentPanel.tsx` (payload/validation + `InlineField` `image` handling)
- `backend/src/main/java/com/platform/controller/ContentController.java` / `impl/ContentControllerImpl.java` (generic `GET /api/content/{type}/{id}`)
