# Coding Profiles Public API

## Overview

Public read-only endpoint for live GitHub and LeetCode profile stats. No authentication required.

---

## 1. Get Coding Profiles

### Endpoint
```
GET /api/content?type=coding-profiles
```

### Response (200 OK)
```json
{
  "coding-profiles": {
    "github": {
      "login": "ishubhamrathi",
      "name": "Shubham Rathi",
      "avatarUrl": "https://avatars.githubusercontent.com/u/40445744?v=4",
      "htmlUrl": "https://github.com/ishubhamrathi",
      "bio": "I am a Student at Lovely Professional...",
      "location": "Faridabad,Haryana,India",
      "company": null,
      "blog": "",
      "twitterUsername": "ishubhamrathi",
      "publicRepos": 46,
      "followers": 1,
      "following": 0,
      "createdAt": "2018-06-21T01:09:22Z"
    },
    "leetcode": {
      "username": "ishubhamrathi",
      "ranking": 346632,
      "reputation": 0,
      "contributionPoints": 2308,
      "totalSolved": 383,
      "totalQuestions": 4068,
      "solvedByDifficulty": {
        "all": 383,
        "easy": 190,
        "medium": 146,
        "hard": 47
      },
      "acceptedSubmissions": 383,
      "totalSubmissions": 387,
      "activeDays": 177,
      "lastActiveAt": "2026-09-28"
    },
    "fetchedAt": "2026-09-28T11:47:13.536291800Z",
    "fromCache": false
  }
}
```

### Response Fields

#### GitHub Object
| Field | Type | Description |
|-------|------|-------------|
| `login` | string | GitHub username |
| `name` | string | Display name |
| `avatarUrl` | string | Profile avatar URL |
| `htmlUrl` | string | Profile URL |
| `bio` | string \| null | Bio |
| `location` | string \| null | Location |
| `company` | string \| null | Company |
| `blog` | string | Blog URL |
| `twitterUsername` | string \| null | Twitter handle |
| `publicRepos` | integer | Public repository count |
| `followers` | integer | Follower count |
| `following` | integer | Following count |
| `createdAt` | ISO 8601 | Account creation date |

#### LeetCode Object
| Field | Type | Description |
|-------|------|-------------|
| `username` | string | LeetCode username |
| `ranking` | integer | Global ranking |
| `reputation` | integer | Reputation points |
| `contributionPoints` | integer | Contribution points |
| `totalSolved` | integer | Total problems solved |
| `totalQuestions` | integer | Total available problems |
| `solvedByDifficulty` | object | Breakdown by difficulty |
| `acceptedSubmissions` | integer | Accepted submissions |
| `totalSubmissions` | integer | Total submissions |
| `activeDays` | integer | Active days count |
| `lastActiveAt` | ISO 8601 (date) | Last active date |

#### Meta Fields
| Field | Type | Description |
|-------|------|-------------|
| `fetchedAt` | ISO 8601 | When data was fetched |
| `fromCache` | boolean | Whether served from 6h cache |

---

## 2. Frontend Integration

```js
async function fetchCodingProfiles() {
  const res = await fetch('/api/content?type=coding-profiles');
  if (!res.ok) throw new Error('Failed to fetch coding profiles');
  return res.json();
}

const { coding-profiles: profiles } = await fetchCodingProfiles();
const { github, leetcode, fromCache } = profiles;
```

---

## 3. Notes

- **Public endpoint** — no `X-API-Key` or session required
- **Cached** — GitHub + LeetCode data cached for 6 hours upstream
- **Caching** — responses include `Cache-Control: public, max-age=300`