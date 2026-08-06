# Admin Panel: Timeline Widget + Notification Center

## Overview

The **Timeline** module (BDUI widget) manages personal timelines, their items (tasks, events,
reminders, milestones), and tracking/metric entries. Data is **scoped to the authenticated user**
(`user_id` is auto-stamped by the backend on create — never send it from the client).

The **Notification Center** is a user-scoped platform capability: in-app notifications
(center, unread badge, history, toasts, snooze, mark read, complete-from-notification) plus
opt-in **FCM browser push** for installed PWAs. Timeline only expresses *what* should happen
(reminder offset before an item's scheduled time); the notification engine decides *when/how*
and delivers through enabled channels.

**Critical:** all requests need `withCredentials: true` (session cookie).

| Endpoint group | Auth |
|---|---|
| `/api/v1/widget/TLM*`, `/api/v1/data/TLM|TLI|TLE` | ADMIN (admin panel) |
| `/api/notifications/**`, `/api/timeline/**` | any authenticated user |

---

## 1. Data Model (summary)

| Entity | Code | Table | Notes |
|---|---|---|---|
| Timeline | `TLM` | `timelines` | name, description, timeline_type, color, icon, is_archived |
| Timeline Item | `TLI` | `timeline_items` | task/event/reminder/milestone, status, priority, scheduled_at, due_at, recurrence JSONB, reminder_enabled + reminder_offset_minutes |
| Timeline Entry | `TLE` | `timeline_entries` | metric_key, metric_value, metric_unit, logged_at (tracking/metrics) |
| Notification | `NTC` | `notifications` | type, title, body, data (action payload), read_at, snoozed_until |
| Push Subscription | `PSU` | `push_subscriptions` | FCM registration tokens per user |

All tables carry `created_at`, `updated_at`, `deleted_at`/`deleted_by` (soft delete), and
`created_by`/`updated_by`. `user_id` is a **system field** — the client cannot set it.

### Timeline Item key fields

| Field | Type | Description |
|---|---|---|
| `item_type` | string | `task` \| `event` \| `reminder` \| `milestone` |
| `status` | string | `pending` \| `in_progress` \| `completed` |
| `priority` | string | `low` \| `medium` \| `high` |
| `scheduled_at` | datetime | when the item happens |
| `due_at` | datetime | optional deadline |
| `recurrence` | JSONB | `{"freq":"DAILY|WEEKLY|MONTHLY|YEARLY","interval":N,"byDay":["MO","WE"],"until":"2026-12-31"}` |
| `reminder_enabled` | boolean | master switch |
| `reminder_offset_minutes` | int | remind N minutes **before** `scheduled_at` (e.g. `15`) |
| `occurrence_count` | int | how many times a recurring item has rolled forward |

Completing a recurring item (via the timeline complete action or a notification action)
automatically rolls it to its next occurrence (`status` resets to `pending`).

---

## 2. Widget Endpoints (BDUI)

### GET /api/v1/widget/TLM — Timelines list

```
GET /api/v1/widget/TLM
Cookie: JSESSIONID=<session>
```

Response `200 OK` (type `timeline-list`):

```json
{
  "type": "timeline-list",
  "title": "Timelines",
  "schema": {
    "columns": [
      { "name": "name", "label": "Timeline", "type": "text" },
      { "name": "timeline_type", "label": "Type", "type": "text" },
      { "name": "itemCount", "label": "Open Items", "type": "number" },
      { "name": "createdAt", "label": "Created", "type": "datetime" }
    ]
  },
  "data": {
    "items": [
      {
        "id": "a1b2...",
        "name": "Morning Routine",
        "description": null,
        "timeline_type": "habit",
        "color": "#4f46e5",
        "icon": "sun",
        "itemCount": 3,
        "createdAt": "2026-08-01T09:00:00"
      }
    ]
  },
  "pagination": { "page": 1, "pageSize": 25, "totalItems": 1, "totalPages": 1 },
  "actions": [
    { "id": "create-timeline", "label": "New Timeline", "type": "modal", "config": { "icon": "plus" }, "permissions": ["ADMIN"] },
    { "id": "open-timeline", "label": "Open", "type": "navigate", "config": { "url": "/api/v1/widget/TLM-D" }, "permissions": ["ADMIN"] },
    { "id": "delete-timeline", "label": "Delete", "type": "confirm", "config": { "icon": "trash" }, "permissions": ["ADMIN"] }
  ],
  "permissions": ["ADMIN"],
  "metadata": { "entityCode": "TLM", "searchable": true }
}
```

### GET /api/v1/widget/TLM-D — Timeline detail

Select a timeline from the list and load its items:

```
GET /api/v1/widget/TLM-D?field=timeline_id&value=<timeline-uuid>
Cookie: JSESSIONID=<session>
```

Response `200 OK` (type `timeline`):

```json
{
  "type": "timeline",
  "title": "Morning Routine",
  "subtitle": "Daily habits",
  "schema": {
    "fields": [
      { "name": "title", "label": "Title", "type": "text", "required": true },
      { "name": "item_type", "label": "Type", "type": "select", "options": ["task", "event", "reminder", "milestone"] },
      { "name": "status", "label": "Status", "type": "select", "options": ["pending", "in_progress", "completed"] },
      { "name": "priority", "label": "Priority", "type": "select", "options": ["low", "medium", "high"] },
      { "name": "scheduled_at", "label": "Scheduled", "type": "datetime" },
      { "name": "due_at", "label": "Due", "type": "datetime" },
      { "name": "description", "label": "Notes", "type": "textarea" }
    ]
  },
  "data": {
    "items": [
      {
        "id": "i1...",
        "itemType": "task",
        "title": "Meditate",
        "status": "pending",
        "priority": "high",
        "scheduledAt": "2026-08-06T06:30:00",
        "dueAt": null,
        "completedAt": null,
        "occurrenceCount": 0,
        "recurrence": "{\"freq\":\"DAILY\",\"interval\":1}",
        "reminderEnabled": true,
        "reminderOffsetMinutes": 15
      }
    ]
  },
  "pagination": { "page": 1, "pageSize": 10, "totalItems": 10, "totalPages": 1 },
  "actions": [
    { "id": "add-item", "label": "Add Item", "type": "modal", "config": { "icon": "plus" }, "permissions": ["ADMIN"] },
    { "id": "complete-item", "label": "Complete", "type": "confirm", "config": { "method": "POST", "url": "/api/timeline/items/{id}/complete" }, "permissions": ["ADMIN"] }
  ],
  "permissions": ["ADMIN"],
  "metadata": { "entityCode": "TLI", "timelineId": "<timeline-uuid>", "saveEndpoint": "/api/v1/data/TLI" }
}
```

### GET /api/v1/widget/TLM-A — Timeline analytics

```
GET /api/v1/widget/TLM-A?field=timeline_id&value=<timeline-uuid>   # optional timeline filter
```

Response `200 OK` (type `metrics`): cards for Total Items, Completed, Completion Rate %,
Overdue, Due Today, Next 7 Days, Tracking Entries.

---

## 3. Timeline CRUD (generic data endpoints)

Entity codes: `TLM` (timelines), `TLI` (timeline items), `TLE` (timeline entries).

| Method | Endpoint | Body (relevant) | Success |
|---|---|---|---|
| `POST` | `/api/v1/data/TLM` | `{ "name": "...", "timeline_type": "habit", "color": "#4f46e5" }` | `201 { "id": "<uuid>" }` |
| `PUT` | `/api/v1/data/TLM/{uuid}` | partial fields | `200 { "updated": true }` |
| `GET` | `/api/v1/data/TLM/{uuid}` | — | `200 { ...row... }` |
| `DELETE` | `/api/v1/data/TLM/{uuid}` | — | `200 { "deleted": true, "soft": true }` |

**Item create example** (reminder expressed as "what" only):

```json
POST /api/v1/data/TLI
{
  "timeline_id": "<timeline-uuid>",
  "item_type": "task",
  "title": "Meditate",
  "status": "pending",
  "priority": "high",
  "scheduled_at": "2026-08-06T06:30:00",
  "recurrence": { "freq": "DAILY", "interval": 1 },
  "reminder_enabled": true,
  "reminder_offset_minutes": 15
}
```

**Tracking entry example**:

```json
POST /api/v1/data/TLE
{
  "timeline_id": "<timeline-uuid>",
  "item_id": "<item-uuid>",
  "metric_key": "steps",
  "metric_value": 8432,
  "metric_unit": "count",
  "logged_at": "2026-08-05T21:00:00"
}
```

Notes:
- `recurrence` is JSONB — send an object (backend binds it as JSON).
- `timeline_id` (item) / `timeline_id`+`item_id` (entry) are required client-supplied FK values.
- Soft delete: tables support it (`deleted_at`), so `DELETE` returns `soft: true`.

### Complete an item (recurrence-aware)

```
POST /api/timeline/items/<item-uuid>/complete
Cookie: JSESSIONID=<session>
```

Response `200 OK`:

```json
{ "completed": true, "status": "pending" }
```

`status` is `"completed"` for one-off items, or `"pending"` when a recurring item rolled to its
next occurrence. `404` if the item is not found or not owned by the user.

---

## 4. Notification Center

Session-scoped (any authenticated user). All responses include `unreadCount` where relevant.

### Endpoints

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/api/notifications?page=1&pageSize=20&unreadOnly=false` | List (history + toast feed) |
| `GET` | `/api/notifications/unread-count` | Unread badge count |
| `POST` | `/api/notifications/{id}/read` | Mark one read |
| `POST` | `/api/notifications/read-all` | Mark all read |
| `POST` | `/api/notifications/{id}/snooze` | Snooze until time (`{"until":"2026-08-06T07:00:00"}`) |
| `POST` | `/api/notifications/{id}/complete` | Execute action (e.g. complete timeline item) + mark read |
| `DELETE` | `/api/notifications/{id}` | Remove from center |
| `POST` | `/api/notifications/subscriptions` | Register FCM token |
| `GET` | `/api/notifications/subscriptions` | List registered tokens |
| `DELETE` | `/api/notifications/subscriptions/{id}` | Unregister token |

### List

```
GET /api/notifications?page=1&pageSize=20
Cookie: JSESSIONID=<session>
```

Response `200 OK`:

```json
{
  "items": [
    {
      "id": "n1...",
      "type": "timeline_reminder",
      "title": "Reminder: Meditate",
      "body": "Scheduled for 2026-08-06T06:30",
      "data": {
        "action": "complete_timeline_item",
        "targetId": "i1..."
      },
      "read": false,
      "snoozedUntil": null,
      "createdAt": "2026-08-06T06:15:00"
    }
  ],
  "unreadCount": 3
}
```

### Unread badge

```
GET /api/notifications/unread-count
```

Response `200 OK`: `{ "count": 3 }` — poll this for the badge (e.g. every 30–60s, or on toast).

### Mark read / read all

```
POST /api/notifications/{id}/read          → 200 { ...NotificationItem... }
POST /api/notifications/read-all           → 200 { "updated": 3 }
```

### Snooze

```
POST /api/notifications/{id}/snooze
Content-Type: application/json

{ "until": "2026-08-06T07:00:00" }
```

Response `200 OK`: the updated `NotificationItem` with `snoozedUntil` set. Hide the
notification until that time (re-appears in the list afterward).

### Complete from notification

```
POST /api/notifications/{id}/complete
```

Response `200 OK`: the updated `NotificationItem` (`read: true`). If the notification carries
`data.action = "complete_timeline_item"`, the referenced timeline item is completed
(recurring items roll forward). `400` when the action is unknown or `targetId` is missing;
`404` when the notification doesn't exist.

### Delete

```
DELETE /api/notifications/{id}   → 200 { "deleted": true }
```

### FCM push subscription

Register the token obtained client-side from Firebase Messaging
(`messaging.getToken(vapidKey)`):

```
POST /api/notifications/subscriptions
Content-Type: application/json

{
  "endpoint": "<fcm-registration-token>",
  "p256dh": "<browser-generated>",
  "auth": "<browser-generated>",
  "userAgent": "Mozilla/5.0 ..."
}
```

Response `201`: `{ "registered": true }` (idempotent upsert per user+endpoint).

**Push is opt-in:** the backend only sends FCM when `FCM_ENABLED=true` plus a service-account
JSON + VAPID key are configured. Without that, in-app notifications still work end-to-end.

---

## 5. Error Codes

| Status | Body | When |
|---|---|---|
| 200 | `{ "updated": true }` / `{ "deleted": true }` / item | success |
| 201 | `{ "id": "<uuid>" }` / `{ "registered": true }` | created |
| 400 | `{ "error": "...", "hint": "..." }` | invalid input, unknown action |
| 401 | *(Spring default)* | no session |
| 404 | `{ "error": "Record not found" }` / `{ "error": "Notification not found" }` | not found / not owned |
| 403 | `{ "error": "Admin access required" }` | ADMIN-only endpoint, non-admin |

---

## 6. Frontend Behavior Checklist

1. **`withCredentials: true` on every request** — the session cookie authorizes everything.
2. **Never send `user_id`** — backend stamps the session user; client-sent values are rejected.
3. **Timeline module** (dashboard menu `timeline` → `TLM`): render the `timeline-list` widget;
   opening a timeline loads `GET /api/v1/widget/TLM-D?field=timeline_id&value=<id>`.
4. **Add/edit items** via `POST/PUT /api/v1/data/TLI` with the `saveEndpoint` metadata;
   send `recurrence` as an object and `reminder_*` fields to express reminder intent.
5. **Complete action** calls `POST /api/timeline/items/{id}/complete` (not generic PUT), then
   refetch the detail widget.
6. **Unread badge**: poll `GET /api/notifications/unread-count`; toasts poll `GET /api/notifications`.
7. **Read/snooze/complete/delete** call the matching notification endpoints; update UI
   optimistically and reconcile with the returned item.
8. **Complete from notification** button: `POST /api/notifications/{id}/complete` — also refreshes
   the timeline detail so the item shows its new state.
9. **PWA push**: register on login/permission grant via `POST /api/notifications/subscriptions`;
   handle `push` events with a service worker; show toast + mark-read on click.
10. After any write, refetch the affected widget to stay consistent (same pattern as existing widgets).
