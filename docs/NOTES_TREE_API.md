# Notes Tree API (Frontend Contract)

Middle-panel tree for Notes uses the **explorer API**, not the widget API.
`GET /api/v1/widget/NT-T` is the right-panel widget wrapper and is not used here.

All endpoints require a session cookie (`credentials: 'include'`) and the `ADMIN` role.

## Endpoint table

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `GET` | `/api/v1/explorer/NT-T` | Load tree (middle panel) |
| `GET` | `/api/v1/data/NT/{uuid}` | Load a note's full content (open a file) |
| `POST` | `/api/v1/data/NT` | Create note/file or folder |
| `PUT` | `/api/v1/data/NT/{uuid}` | Update note/file (rename, move, save content, persist UI state) |
| `DELETE` | `/api/v1/data/NT/{uuid}` | Delete note/file |
| `PATCH` | `/api/v1/data/NT/folder` | Rename/move a folder (bulk) |
| `DELETE` | `/api/v1/data/NT/folder?path=...` | Delete a folder and everything under it (bulk) |

## Load tree

```
GET /api/v1/explorer/NT-T
```

```json
{
  "type": "tree",
  "schema": { "nodeKey": "path", "childrenKey": "children", "labelKey": "name" },
  "data": {
    "tree": [
      {
        "name": "Work", "path": "Work", "parentPath": null, "level": 0, "type": "folder",
        "id": "<folder-uuid>", "expanded": false,
        "children": [
          {
            "name": "Meetings", "path": "Work/Meetings", "parentPath": "Work", "level": 1,
            "type": "folder", "id": "<folder-uuid>", "expanded": true,
            "children": [
              {
                "name": "Agenda", "path": "Work/Meetings/Agenda", "parentPath": "Work/Meetings",
                "level": 2, "type": "file", "id": "<uuid>", "lastOpenedAt": "2026-08-02T19:00Z"
              }
            ]
          }
        ]
      }
    ],
    "totalItems": 3
  }
}
```

Node fields:
- `"folder"` — expandable, has `children[]`. `id` = the folder row's UUID (the is_folder
  record at that path; `""` if no folder row exists yet), `expanded` = persisted
  expand/collapse state (default `false`).
- `"file"` — leaf, selectable, has `id` (use it for open/update/delete) and
  `lastOpenedAt` (ISO-8601, or `null` if never opened).

Render tree using `schema.nodeKey` (`path`) as the node id, `schema.childrenKey`
(`children`) for nesting, `schema.labelKey` (`name`) for the label.

## Create

Create a note/file:

```
POST /api/v1/data/NT
Content-Type: application/json

{ "title": "Agenda", "folder_path": "Work/Meetings", "content": "<richtext>" }
```

```
201 { "id": "<uuid>" }
```

Create a folder (empty folders are allowed and visible):

```
POST /api/v1/data/NT
Content-Type: application/json

{ "title": "Meetings", "folder_path": "Work/Meetings", "is_folder": true }
```

```
201 { "id": "<uuid>" }
```

`is_folder` distinguishes folders from files. Omit it (or set `false`) for notes/files.

## Update / delete a note/file

```
PUT /api/v1/data/NT/{uuid}
{ "title": "New Title", "folder_path": "Work/Meetings/Archive" }
```

```
200 { "updated": true }
```

`folder_path` on a file moves it in the tree.

```
DELETE /api/v1/data/NT/{uuid}
```

Soft-delete (the `notes` table has a `deleted_at` column — the row is stamped and hidden from queries):

```
200 { "deleted": true, "soft": true }
```

## Mark opened / expand-collapse (PUT)

PUT accepts any writable column. Use it for UI state that should persist.

Mark a note as opened (send the current client time as ISO-8601):

```
PUT /api/v1/data/NT/{uuid}
Content-Type: application/json

{ "last_opened_at": "2026-08-02T19:00:00.000Z" }
```

```
200 { "updated": true }
```

Persist a folder's expanded/collapsed state (folder node `id` from the tree):

```
PUT /api/v1/data/NT/{folderUuid}
Content-Type: application/json

{ "expanded": true }
```

```
200 { "updated": true }
```

`last_opened_at` (`timestamptz`) and `expanded` (`boolean`, default `false`) are
plain columns — PUT them through the existing CRUD endpoint, no extra verbs.
`404 { "error": "Record not found", "hint": null }` when the uuid does not exist.

## Open a file (load content)

Tree file nodes carry only `id`/`name`/`path` — fetch the full note (including
richtext `content`) when the user opens it:

```
GET /api/v1/data/NT/{uuid}
```

```
200 {
  "id": "<uuid>",
  "title": "Agenda",
  "folder_path": "Work/Meetings",
  "content": "<richtext>",
  "created_at": "...",
  "updated_at": "..."
}
```

`404 { "error": "Record not found", "hint": null }` when the uuid does not exist.

## Folder bulk operations

Rename or move a folder (updates the folder row and every descendant's `folder_path`):

```
PATCH /api/v1/data/NT/folder
Content-Type: application/json

{ "oldPath": "Work", "newPath": "Projects" }
```

```
200 { "updated": 3 }
```

Delete a folder and everything under it:

```
DELETE /api/v1/data/NT/folder?path=Work/Meetings
```

```
200 { "deleted": true, "count": 5 }
```

## Errors

| Status | Body | When |
|--------|------|------|
| 400 | `{ "error": "...", "hint": null }` | Bad/missing `oldPath`/`newPath`/`path`, invalid entity code |
| 403 | Spring default (empty body) | Not authenticated |
| 403 | `{ "error": "Admin access required" }` | Authenticated but not ADMIN |
| 404 | `{ "error": "Record not found", "hint": null }` | UUID not found |
| 500 | `{ "error": "...", "hint": null }` | Server error |

## Critical rules

- Always send `credentials: 'include'` (session cookie).
- `folder_path` uses `/` separators. Rows with blank `folder_path` are not shown in the tree.
- After any mutation, refetch `GET /api/v1/explorer/NT-T` — the backend owns tree assembly; do not patch the tree client-side.
