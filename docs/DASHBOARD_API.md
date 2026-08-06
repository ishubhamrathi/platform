# Dashboard API

## Three-Panel Layout

```
┌─────────────────────────────────────────────────────────────┐
│  LEFT PANEL     │  MIDDLE PANEL       │  RIGHT PANEL        │
│  (Module Select)│  (Explorer)          │  (Content)          │
│                 │                      │                     │
│  menus[].title  │  navigationType:     │  contentWidgets:    │
│  Admin          │  "list" | "tree"    │  entity codes for   │
│  Notes          │   | "file-tree"     │  right-panel widgets│
│  QSheets        │                      │                     │
│                 │                      │                     │
│  Notes ▼        │  Work ▼             │  ┌───────────────┐  │
│  └─Folders&Files│  ├─Meetings         │  │ Note Editor   │  │
│                 │  └─Ideas            │  │               │  │
│  Admin ▼        │  [+] New Folder     │  └───────────────┘  │
│  ├─Users        │                      │                     │
│  └─Assets       │                      │                     │
└─────────────────────────────────────────────────────────────┘
```

**Left panel** — top-level module selector driven by `MenuItem[]`.
**Middle panel** — explorer/navigation driven by `navigationType` ("list", "tree", "file-tree").
**Right panel** — content widgets driven by `contentWidgets[]`.

---

## Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `GET` | `/api/v1/dashboard` | Workspace layout |
| `GET` | `/api/v1/explorer/{source}` | Middle-panel navigation data |
| `GET` | `/api/v1/widget/{entityCode}` | Right-panel widget data |
| `GET` | `/api/v1/data/{entityCode}/{uuid}` | Get single record |
| `POST` | `/api/v1/data/{entityCode}` | Create record |
| `PUT` | `/api/v1/data/{entityCode}/{uuid}` | Update record |
| `PATCH` | `/api/v1/data/{entityCode}/folder` | Rename/move a folder (tree entities) |
| `DELETE` | `/api/v1/data/{entityCode}/{uuid}` | Delete record (soft-delete if table has `deleted_at`) |
| `DELETE` | `/api/v1/data/{entityCode}/folder?path=...` | Delete a folder and its descendants |
| `GET` | `/api/v1/data/{entityCode}/distinct?columns=a,b` | Distinct column values |
| `GET` | `/api/v1/data/{entityCode}/path-suggestions?q=...` | Path autocomplete |

All endpoints require session cookie and admin role.

---

## Dashboard Contract

### GET /api/v1/dashboard

```json
{
  "menus": [
    {
      "id": "admin", "title": "Admin", "icon": "shield",
      "children": [
        { "id": "USR", "title": "Users", "icon": "users",
          "navigationType": "list", "explorerSource": null,
          "contentWidgets": ["USR"] },
        { "id": "AST", "title": "Assets", "icon": "file",
          "navigationType": "list", "explorerSource": null,
          "contentWidgets": ["AST"] }
      ]
    },
    {
      "id": "notes", "title": "Notes", "icon": "file-text",
      "children": [
        { "id": "NT-T", "title": "Notes", "icon": "tree-view",
          "navigationType": "tree", "explorerSource": "NT-T",
          "contentWidgets": ["NT-ED"] }
      ]
    }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `navigationType` | `"list"`, `"tree"`, `"file-tree"` | How middle panel renders |
| `explorerSource` | `string` or `null` | Entity code for lazy-loading tree data (`null` for list) |
| `contentWidgets` | `string[]` | Entity codes for right-panel widgets |

---

## Explorer Contract (Middle Panel)

### GET /api/v1/explorer/{source}

Fetched lazily when module is selected. For `"list"` type no call is needed (items are in `children`).

```json
// GET /api/v1/explorer/NT-T
{
  "type": "tree",
  "schema": { "nodeKey": "path", "childrenKey": "children", "labelKey": "name" },
  "data": {
    "tree": [
      {
        "name": "Work", "path": "Work", "parentPath": null, "level": 0,
        "type": "folder",
        "children": [
          { "name": "Meetings", "path": "Work/Meetings", "level": 1,
            "type": "folder", "children": [] }
        ]
      }
    ],
    "totalItems": 5
  }
}
```

Tree node types: `"folder"` (expandable, has `children[]`) and `"file"` (leaf, selectable).
Nodes also carry `id` (entity PK); folders carry `expanded` and files carry `lastOpenedAt`.

---

## Widget Contract (Right Panel)

### GET /api/v1/widget/{entityCode}

Fetched when a middle-panel navigation item is selected.

```json
// Table widget
{
  "type": "table",
  "title": "Users",
  "schema": {
    "columns": [
      { "name": "id", "label": "ID", "type": "string", "sortable": true, "filterable": true },
      { "name": "title", "label": "Title", "type": "text", "sortable": true, "filterable": true }
    ]
  },
  "data": { "items": [] },
  "pagination": { "page": 1, "pageSize": 25, "totalItems": 0, "totalPages": 1 },
  "actions": [
    { "id": "create", "label": "Create", "type": "modal", "config": { "icon": "plus" }, "permissions": ["ADMIN"] }
  ],
  "permissions": ["ADMIN"],
  "metadata": { "entityCode": "USR", "searchable": true }
}
```

```json
// Editor widget
{
  "type": "editor",
  "title": "Note Editor",
  "schema": {
    "fields": [
      { "name": "title", "label": "Title", "type": "text", "required": true },
      { "name": "content", "label": "Content", "type": "richtext", "required": false }
    ]
  },
  "data": {},
  "actions": [
    { "id": "save-note", "label": "Save", "type": "modal", "config": {}, "permissions": ["ADMIN"] }
  ],
  "metadata": { "entityCode": "NT", "editor": "blocknote", "richText": true, "saveEndpoint": "/api/v1/data/NT" }
}
```

**Widget types:** `"table"`, `"editor"`, `"metrics"`.

**Query params for table:** `?field=title&value=test` (filter), `?sortBy=created_at&sortOrder=desc` (sort), `?search=keyword` (search), `?page=2&pageSize=25` (pagination).

---

## Data CRUD Contract

| Method | Endpoint | Success Response |
|--------|----------|-----------------|
| `GET` | `/api/v1/data/{entityCode}/{uuid}` | `200 { ...row as key/value map... }` |
| `POST` | `/api/v1/data/{entityCode}` | `201 { "id": "uuid" }` |
| `PUT` | `/api/v1/data/{entityCode}/{uuid}` | `200 { "updated": true }` |
| `DELETE` | `/api/v1/data/{entityCode}/{uuid}` | `200 { "deleted": true }` — or `{ "deleted": true, "soft": true }` when the table has a `deleted_at` column |

---

## Error Codes

| Status | Body | When |
|--------|------|------|
| 400 | `{ "error": "...", "hint": "..." }` | Invalid input or entity code (`ApiError`; `hint` omitted when null) |
| 403 | *(empty body, Spring Security default)* | Not authenticated |
| 403 | `{ "error": "Admin access required" }` | Authenticated but not admin role |
| 404 | `{ "error": "Record not found" }` | UUID not found |
| 500 | `{ "error": "..." }` | Server error |

---

## Adding a Module (Backend)

Modules are configuration-driven — no controller/service code changes required.

**1.** Register the entity in `src/main/resources/entity-registry.yaml`:
```yaml
- code: PRJ
  table: projects
  widget: projects
  uuid-column: project_id
```

**2.** (Optional) Add a specialized widget provider implementing `WidgetProvider` (registered in the `widget` engine) if the default dynamic table widget isn't enough.

**3.** Add the menu entry in `src/main/resources/dashboard-definition.yaml`:
```yaml
- id: projects
  title: Projects
  icon: folder-open
  children:
    - id: PRJ
      title: All Projects
      icon: folder-open
      navigation-type: list
      content-widgets:
        - PRJ

    # Tree module (middle panel lazy-loads GET /api/v1/explorer/{explorer-source})
    - id: DOC-T
      title: Document Tree
      icon: tree-view
      navigation-type: tree
      explorer-source: DOC-T
      content-widgets:
        - DOC-ED
```

`EntityMapper` indexes the registry at startup; the dashboard is served from the YAML by `BduiDashboardService`.
