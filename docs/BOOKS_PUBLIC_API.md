# Books Public API

## Overview

Public read-only endpoints for the portfolio books section. No authentication required.

---

## 1. List Books

### Endpoint
```
GET /api/content?type=books
```

### Query Parameters
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `type` | string | — | Must be `books` |
| `books_limit` | integer | 50 | Max books to return (max 100) |

### Example Requests
```
GET /api/content?type=books
GET /api/content?type=books&books_limit=20
```

### Response (200 OK)
```json
{
  "books": {
    "books": [
      {
        "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
        "title": "Clean Code",
        "author": "Robert C. Martin",
        "description": "A handbook of agile software craftsmanship.",
        "coverUrl": "https://covers.openlibrary.org/b/id/8471961-L.jpg",
        "coverUrlLarge": "https://covers.openlibrary.org/b/id/8471961-L.jpg",
        "coverUrlSpine": null,
        "coverUrlBack": null,
        "genre": "Software Engineering",
        "googleLink": "https://books.google.com/books?id=23iAl3JY9rAC",
        "openLibraryKey": "OL44598888M",
        "isbn13": "9780132350884",
        "isbn10": "0132350882",
        "publisher": "Prentice Hall",
        "publishedYear": 2008,
        "pageCount": 464,
        "language": "en",
        "dimensionsCm": "23.5x19x3.2",
        "spineWidthCm": 2.8,
        "modelUrl": null,
        "shelfPosition": null,
        "shelfRow": null,
        "rotationYDeg": 0,
        "customData": null,
        "isFeatured": true,
        "displayOrder": 0,
        "createdAt": "2025-01-15T10:30:00.000+00:00",
        "updatedAt": "2025-01-15T10:30:00.000+00:00",
        "externalUrl": "https://openlibrary.org/books/OL44598888M"
      }
    ],
    "count": 1
  }
}
```

### Response Fields
| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Unique book identifier |
| `title` | string | Book title |
| `author` | string | Author name |
| `description` | string \| null | Short summary |
| `coverUrl` | string \| null | Cover image URL (medium) |
| `coverUrlLarge` | string \| null | High-res cover for 3D texture |
| `coverUrlSpine` | string \| null | Spine image for 3D bookshelf |
| `coverUrlBack` | string \| null | Back cover image for 3D bookshelf |
| `genre` | string \| null | Genre/category |
| `googleLink` | string \| null | Google Books URL |
| `openLibraryKey` | string \| null | Open Library key (e.g. `OL44598888M`) |
| `isbn13` | string \| null | ISBN-13 |
| `isbn10` | string \| null | Legacy ISBN-10 |
| `publisher` | string \| null | Publisher name |
| `publishedYear` | integer \| null | Publication year |
| `pageCount` | integer \| null | Number of pages |
| `language` | string \| null | ISO 639-1 language code (e.g. `en`) |
| `dimensionsCm` | string \| null | Physical dimensions "HxWxD" in cm |
| `spineWidthCm` | number \| null | Spine thickness in cm |
| `modelUrl` | string \| null | Optional GLTF/GLB 3D model URL |
| `shelfPosition` | integer \| null | Manual left-to-right shelf position |
| `shelfRow` | integer \| null | Shelf row (0 = bottom) |
| `rotationYDeg` | integer | Yaw rotation in degrees (0-359) |
| `customData` | object \| null | Extensible JSON for series, volume, etc. |
| `externalUrl` | string \| null | Computed link to source (Open Library/Google Books) |
| `isFeatured` | boolean | Featured on homepage |
| `displayOrder` | integer | Sort order (ascending) |
| `createdAt` | ISO 8601 | Creation timestamp |
| `updatedAt` | ISO 8601 | Last update timestamp |
| `count` | integer | Total books returned |

---

## 2. Single Book Detail

### Endpoint
```
GET /api/content?type=books&id={uuid}
```

### Query Parameters
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | yes | Must be `books` |
| `id` | UUID | yes | Book UUID |

### Example Request
```
GET /api/content?type=books&id=a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

### Response (200 OK)
```json
{
  "book": {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "title": "Clean Code",
    "author": "Robert C. Martin",
    "description": "A handbook of agile software craftsmanship.",
    "coverUrl": "https://covers.openlibrary.org/b/id/8471961-L.jpg",
    "genre": "Software Engineering",
    "googleLink": "https://books.google.com/books?id=23iAl3JY9rAC",
    "isFeatured": true,
    "displayOrder": 0,
    "createdAt": "2025-01-15T10:30:00.000+00:00",
    "updatedAt": "2025-01-15T10:30:00.000+00:00"
  }
}
```

### Response (404 Not Found)
```json
{
  "error": "Book not found",
  "message": "No book found with id: a1b2c3d4-e5f6-7890-abcd-ef1234567890"
}
```

---

## 3. Frontend Integration

### Fetch All Books
```js
async function fetchBooks(limit = 50) {
  const res = await fetch(`/api/content?type=books&books_limit=${limit}`);
  if (!res.ok) throw new Error('Failed to fetch books');
  return res.json();
}

// Usage
const { books, count } = await fetchBooks(20);
```

### Fetch Single Book
```js
async function fetchBook(id) {
  const res = await fetch(`/api/content?type=books&id=${id}`);
  if (!res.ok) {
    if (res.status === 404) return null;
    throw new Error('Failed to fetch book');
  }
  return res.json();
}

// Usage
const { book } = await fetchBook('a1b2c3d4-e5f6-7890-abcd-ef1234567890');
```

### Render Cover Image
```html
<img
  src={book.coverUrl}
  alt={`${book.title} cover`}
  class="book-cover"
  onerror="this.src='/placeholder-book-cover.png'"
/>

<a href={book.googleLink} target="_blank" rel="noreferrer">
  View on Google Books
</a>
```

### Featured Books
```js
const featuredBooks = books.filter(b => b.isFeatured);
```

### Sort Order
```js
// Sort by displayOrder ascending, then title alphabetical
books.sort((a, b) => a.displayOrder - b.displayOrder || a.title.localeCompare(b.title));
```

---

## 4. Error Responses

| Status | Code | Description |
|--------|------|-------------|
| 400 | `INVALID_PARAM` | Invalid `books_limit` (must be 1-100) |
| 404 | `NOT_FOUND` | Book not found for given ID |
| 500 | `SERVER_ERROR` | Internal server error |

---

## 5. Notes

- **Only active books** (`is_active = true`) are returned
- **Public endpoint** — no `X-API-Key` or session required
- **Caching** — responses include `Cache-Control: public, max-age=300`
- **Rate limiting** — standard API rate limits apply