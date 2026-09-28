# AMA Suggestions Public API

## Overview

Public read-only endpoint for active AMA (Ask Me Anything) suggested questions. No authentication required.

---

## 1. List Suggestions

### Endpoint
```
GET /api/content?type=suggestions
```

### Response (200 OK)
```json
{
  "suggestions": {
    "suggestions": [
      {
        "id": "58ac115e-6d89-4381-889d-671ebb19579e",
        "question": "Can Shubham explain a complex system using a pizza analogy?",
        "category": null,
        "displayOrder": 0,
        "active": true
      },
      {
        "id": "092526ae-01a1-42ff-b392-b8a5f206327f",
        "question": "Would Shubham survive a zombie apocalypse?",
        "category": "weird,personal",
        "displayOrder": 4,
        "active": true
      }
    ],
    "count": 5
  }
}
```

### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Unique suggestion identifier |
| `question` | string | The suggested question text |
| `category` | string \| null | Category/tags (comma-separated) |
| `displayOrder` | integer | Display order (ascending) |
| `active` | boolean | Whether suggestion is active |
| `count` | integer | Total active suggestions |

---

## 2. Frontend Integration

```js
async function fetchSuggestions() {
  const res = await fetch('/api/content?type=suggestions');
  if (!res.ok) throw new Error('Failed to fetch suggestions');
  return res.json();
}

const { suggestions, count } = await fetchSuggestions();
// suggestions is an array of suggestion objects
```

---

## 3. Notes

- **Public endpoint** — no `X-API-Key` or session required
- **Active only** — only `active: true` suggestions are returned
- **Ordered** — sorted by `displayOrder` ascending
- **Caching** — responses include `Cache-Control: public, max-age=300`