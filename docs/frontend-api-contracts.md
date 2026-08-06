# Admin Platform — API Contract Specification

> **Status:** Draft v1.0  
> **Audience:** Backend (Spring Boot) and Frontend (React) teams  
> **Principle:** Contract-first. Backend implements these contracts. Frontend renders from them.

---

## 1. API Endpoints

### 1.1 Get Available Tabs

```
GET /admin/tabs
```

Returns the list of top-level navigation tabs available to the current user.

**Response: `TabResponse`**

```json
{
  "tabs": [
    {
      "id": "users",
      "title": "Users",
      "icon": "users",
      "badge": null,
      "hidden": false,
      "permission": "admin:users:view"
    },
    {
      "id": "payments",
      "title": "Payments",
      "icon": "credit-card",
      "badge": { "text": "3", "variant": "error" },
      "hidden": false,
      "permission": "admin:payments:view"
    },
    {
      "id": "featureFlags",
      "title": "Feature Flags",
      "icon": "toggle",
      "badge": null,
      "hidden": false,
      "permission": "admin:features:view"
    }
  ]
}
```

**Error Responses**

| Status | Meaning |
|--------|---------|
| `401` | Not authenticated |
| `403` | User has no tabs (no permissions) |

---

### 1.2 Get Sidebar Items for a Tab

```
GET /admin/navigation/{tabId}/sidebar
```

Returns the sidebar navigation items for a given top-level tab.

**Response: `NavItemResponse`**

```json
{
  "items": [
    { "id": "dashboard", "label": "Dashboard", "icon": "layout-dashboard" },
    { "id": "users", "label": "Users", "icon": "users", "badge": { "text": "1284", "variant": "info" } },
    { "id": "roles", "label": "Roles", "icon": "shield" },
    { "id": "permissions", "label": "Permissions", "icon": "key" },
    { "id": "contracts", "label": "Contracts", "icon": "file-text" },
    { "id": "widgets", "label": "Widgets", "icon": "puzzle" },
    { "id": "settings", "label": "Settings", "icon": "settings" }
  ]
}
```

---

### 1.3 Get Page Definition for a Sidebar Item

```
GET /admin/navigation/{tabId}/sidebar/{itemId}/page
```

Returns the full screen definition for a sidebar item, including layout, sections, widgets, and actions.

**Response: `GetTabResponse`**

```json
{
  "screen": {
    "id": "users-screen",
    "title": "User Management",
    "description": "Manage system users, roles, and permissions",
    "layout": {
      "type": "single-column",
      "gap": "lg",
      "maxWidth": "xl",
      "align": "stretch"
    },
    "sections": [
      {
        "id": "search-section",
        "title": "Search",
        "widgets": [
          {
            "id": "search-widget",
            "type": "form",
            "title": null,
            "props": {
              "fields": [
                {
                  "name": "q",
                  "type": "text",
                  "label": "Search",
                  "placeholder": "Search users...",
                  "required": false
                }
              ],
              "submitAction": {
                "id": "search-submit",
                "type": "api-call",
                "label": "Search",
                "params": { "q": { "type": "user-input", "source": "q" } }
              }
            ]
          }
        ],
        "span": 1
      },
      {
        "id": "filters-section",
        "title": "Filters",
        "widgets": [
          {
            "id": "status-filter",
            "type": "chip",
            "title": null,
            "props": {
              "label": "Status",
              "options": [
                { "value": "active", "label": "Active" },
                { "value": "inactive", "label": "Inactive" }
              ],
              "selection": "multiple"
            }
          }
        ],
        "span": 1
      },
      {
        "id": "stats-section",
        "title": null,
        "widgets": [
          {
            "id": "total-users",
            "type": "statistics",
            "title": null,
            "props": {
              "label": "Total Users",
              "value": 1284,
              "change": "+12%",
              "changeType": "up",
              "icon": { "name": "users", "size": 20 }
            }
          },
          {
            "id": "active-users",
            "type": "statistics",
            "title": null,
            "props": {
              "label": "Active Users",
              "value": 1102,
              "change": "+3%",
              "changeType": "up",
              "icon": { "name": "user-check", "size": 20 }
            }
          },
          {
            "id": "banned-users",
            "type": "statistics",
            "title": null,
            "props": {
              "label": "Banned Users",
              "value": 47,
              "change": "-2%",
              "changeType": "down",
              "icon": { "name": "ban", "size": 20 }
            }
          }
        ],
        "span": 1
      },
      {
        "id": "users-table",
        "title": null,
        "widgets": [
          {
            "id": "users-table-widget",
            "type": "table",
            "title": null,
            "props": {
              "columns": [
                { "key": "id", "header": "ID", "width": 80, "sortable": true },
                { "key": "name", "header": "Name", "sortable": true, "searchField": true },
                { "key": "email", "header": "Email", "sortable": true },
                { "key": "role", "header": "Role", "width": 120 },
                { "key": "status", "header": "Status", "width": 100, "renderer": "badge" },
                { "key": "actions", "header": "", "width": 120, "renderer": "action", "actions": [
                  { "id": "view-user", "type": "navigate", "label": "View", "params": { "url": "/admin/users/${row.id}" } },
                  { "id": "delete-user", "type": "delete", "label": "Delete", "confirm": { "title": "Delete User", "message": "Are you sure you want to delete ${row.name}?" } }
                ]}
              ],
              "rows": [...],
              "pagination": { "page": 1, "pageSize": 20, "totalItems": 1284, "totalPages": 64, "mode": "page" },
              "sorting": [{ "field": "name", "direction": "asc" }],
              "selection": { "mode": "multiple", "selectedIds": [], "bulkActions": [{ "id": "bulk-delete", "type": "delete", "label": "Delete Selected" }] },
              "export": { "csv": true, "excel": true, "pdf": false, "filename": "users-export" }
            }
          }
        ],
        "span": 1
      }
    ],
    "actions": [
      {
        "id": "create-user",
        "type": "modal",
        "label": "New User",
        "icon": "plus",
        "variant": "primary",
        "params": { "modal": "user-form", "title": "Create User" }
      },
      {
        "id": "export-users",
        "type": "export",
        "label": "Export CSV",
        "icon": "download",
        "variant": "secondary"
      }
    ],
    "metadata": {
      "breadcrumbs": [
        { "label": "Admin", "href": "/admin" },
        { "label": "Users", "current": true }
      ],
      "version": "1.0.0",
      "lastUpdated": "2026-07-27T18:00:00Z"
    }
  },
  "metadata": {
    "tabId": "users",
    "generatedAt": "2026-07-27T18:00:00Z",
    "ttl": 60
  }
}
```

---

### 1.3 Execute Action

```
POST /admin/actions/{actionId}
```

Executes a widget or screen-level action on the backend.

**Request:**

```json
{
  "actionId": "delete-user",
  "params": {
    "id": "usr_abc123"
  },
  "context": {
    "screenId": "users-screen",
    "selectedRows": ["usr_abc123", "usr_def456"]
  }
}
```

**Response:**

```json
{
  "success": true,
  "result": null,
  "refresh": true,
  "toast": {
    "message": "User deleted successfully",
    "variant": "success",
    "duration": 3000
  },
  "navigation": {
    "type": "replace",
    "url": "/admin/users"
  }
}
```

---

### 1.4 Get Metadata (permissions, features, flags)

```
GET /admin/metadata
```

**Response:**

```json
{
  "version": "1.0.0",
  "permissions": ["admin:users:view", "admin:users:create", "admin:users:delete", "admin:payments:view"],
  "features": {
    "advancedSearch": true,
    "bulkActions": true,
    "export": true,
    "multiSort": false
  },
  "flags": {
    "newDashboard": false,
    "maintenanceMode": false
  }
}
```

---

## 2. Contract Interfaces (Visual)

### 2.1 Request Lifecycle

```
┌──────────┐     ┌───────────────┐     ┌──────────────────┐     ┌────────────────┐
│  Browser  │────▶│  GET /admin/tabs │────▶│  TabController   │────▶│  TabService    │
│           │     │  (authenticated)│     │  ──▶ TabProvider │     │  ──▶ returns  │
│           │     │                 │     │                  │     │  Tab[]         │
│           │     │                 │     │                  │     └────────────────┘
│           │     │  GET /admin/screens/{tabId}│              │
│           │     │  (with query    │────▶│  ScreenController│────▶│ ScreenBuilder  │
│           │     │   params)       │     │                  │     │  ──▶ screen   │
│           │     │                 │     │                  │     │  definition    │
│           │     │                 │     │                  │     └────────────────┘
│           │     │  POST /admin/actions/{id}    │            │
│           │     │  {actionId, params}│          │  ActionController│────▶│ ActionExecutor│
│           │     │                 │     │                  │     │  ──▶ executes│
└──────────┘     └───────────────┘     └──────────────────┘     └────────────────┘
```

### 2.2 Screen Rendering Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                      Frontend Rendering Engine                  │
│                                                                 │
│  GET /admin/tabs ──────────────────────────▶ Tab[]             │
│         │                                                     │
│         ▼                                                     │
│  ┌──────────────┐      User clicks tab                       │
│  │ TabRenderer  │──────────────────────────────┐               │
│  └──────────────┘                              │               │
│         │                                      ▼               │
│         │                    GET /admin/screens/{tabId}        │
│         │                              │                        │
│         │                              ▼                        │
│         │                    ┌─────────────────────┐          │
│         │                    │   ScreenDefinition   │          │
│         │                    │  { layout, sections, │          │
│         │                    │   widgets, actions }  │          │
│         │                    └──────────┬──────────┘          │
│         │                               │                       │
│         ▼                               ▼                       │
│  ┌─────────────────────────────────────────────────────┐       │
│  │              SectionRenderer                        │       │
│  │  Iterates over screen.sections                      │       │
│  │  ┌─────────────────────────────────────────────┐    │       │
│  │  │              WidgetRenderer                 │    │       │
│  │  │  Looks up widget.type in WidgetRegistry    │    │       │
│  │  │  │                                         │    │       │
│  │  │  │   ┌─────────────────────────────────┐  │    │       │
│  │  │  │   │     WidgetRegistry              │  │    │       │
│  │  │  │   │  Map<WidgetType, React.Component>│  │    │       │
│  │  │  │   │  CARD ─────▶ CardRenderer       │  │    │       │
│  │  │  │   │  TABLE ────▶ TableRenderer      │  │    │       │
│  │  │  │   │  FORM ─────▶ FormRenderer       │  │    │       │
│  │  │  │   │  CHART ────▶ ChartRenderer      │  │    │       │
│  │  │  │   │  ACTIVITY ─▶ ActivityRenderer   │  │    │       │
│  │  │  │   │  TABLE ────▶ TableRenderer      │  │    │       │
│  │  │  │   │  ...extensible without changes  │  │    │       │
│  │  │  │   └─────────────────────────────────┘  │    │       │
│  │  │  │                                         │    │       │
│  │  │  ▼                                         │    │       │
│  │  │  React Component with typed props         │    │       │
│  │  │  from WidgetDefinition.props (JSON)       │    │       │
│  │  └─────────────────────────────────────────────┘    │       │
│  │                               │                       │       │
│  │                               ▼                       │       │
│  │  ┌─────────────────────────────────────────────┐    │       │
│  │  │            ActionExecutor                   │    │       │
│  │  │  Handles widget/screen-level actions:       │    │       │
│  │  │  navigate, api-call, modal, download, etc. │    │       │
│  │  └─────────────────────────────────────────────┘    │       │
│  └─────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

### 2.3 Widget Registry Pattern

```
┌─────────────────────────────────────────────────────────────────────┐
│                         WidgetRegistry                              │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  interface WidgetRenderer {                                 │   │
│  │    type: WidgetType;                                        │   │
│  │    component: React.ComponentType<WidgetProps>;             │   │
│  │    defaultProps?: Partial<WidgetDefinition['props']>;       │   │
│  │    validation?: (props: unknown) => boolean;                │   │
│  │  }                                                         │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  class WidgetRegistryImpl implements WidgetRegistry {       │   │
│  │    private renderers: Map<WidgetType, WidgetRenderer> =     │   │
│  │      new Map();                                             │   │
│  │                                                              │   │
│  │    register(renderer: WidgetRenderer): void { ... }         │   │
│  │    get(type: WidgetType): WidgetRenderer | undefined { ... }│   │
│  │    has(type: WidgetType): boolean { ... }                   │   │
│  │    getAllTypes(): WidgetType[] { ... }                      │   │
│  │  }                                                         │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  Registration Examples:                                            │
│  ┌──────────────┬──────────────────────────────────────────┐      │
│  │  WidgetType  │  Component                                │      │
│  ├──────────────┼──────────────────────────────────────────┤      │
│  │  'card'      │  CardRenderer                             │      │
│  │  'statistics'│  StatisticsRenderer                       │      │
│  │  'table'     │  TableRenderer                            │      │
│  │  'form'      │  FormRenderer                             │      │
│  │  'chart'     │  ChartRenderer                            │      │
│  │  'activity'  │  ActivityFeedRenderer                     │      │
│  │  'logs'      │  LogsRenderer                             │      │
│  │  'query-     │  QueryExecutorRenderer                    │      │
│  │  executor'   │                                           │      │
│  │  'kpi'       │  KPIRenderer                              │      │
│  │  'banner'    │  BannerRenderer                           │      │
│  │  'empty-     │  EmptyStateRenderer                       │      │
│  │  state'      │                                           │      │
│  │  'loading'   │  LoadingStateRenderer                     │      │
│  │  'tabs'      │  TabsRenderer                             │      │
│  │  'json-view' │  JsonViewerRenderer                       │      │
│  │  'code-edit' │  CodeEditorRenderer                       │      │
│  │  ...         │  ... (extensible via register())         │      │
│  └──────────────┴──────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. Widget Contract Contract

Every widget must implement this contract so the renderer can display it.

```json
{
  "id": "unique-widget-id",
  "type": "card",
  "title": "Optional title displayed above widget",
  "description": "Optional description",
  "span": 1,
  "visible": true,
  "permission": "optional:permission:to:view",
  "conditions": [
    { "field": "role", "operator": "eq", "value": "admin" }
  ],
  "actions": [
    {
      "id": "widget-action",
      "type": "api-call",
      "label": "Refresh",
      "icon": "refresh",
      "params": { "endpoint": "/admin/stats", "method": "GET" }
    }
  ],
  "props": { "key1": "value1", "key2": 42 }
}
```

---

## 4. Design Patterns (Backend)

### 4.1 Factory — Screen Definition Builder

```java
public interface ScreenBuilder {
    Screen build(ScreenRequest request);
}

public class UsersScreenBuilder implements ScreenBuilder {
    private final WidgetBuilderFactory widgetFactory;
    private final ActionFactory actionFactory;

    public UsersScreenBuilder(WidgetBuilderFactory widgetFactory,
                              ActionFactory actionFactory) {
        this.widgetFactory = widgetFactory;
        this.actionFactory = actionFactory;
    }

    @Override
    public Screen build(ScreenRequest request) {
        return Screen.builder()
            .id("users-screen")
            .title("User Management")
            .layout(LayoutDefinition.singleColumn())
            .addSection(searchSection())
            .addSection(statsSection())
            .addSection(tableSection())
            .addAction(createUserAction())
            .exportAction(exportUsersAction())
            .build();
    }
}
```

### 4.2 Strategy — Widget Builders

```java
public interface WidgetBuilder {
    WidgetDefinition build(WidgetRequest request);
    WidgetType getType();
}

@Component
public class CardWidgetBuilder implements WidgetBuilder {
    @Override
    public WidgetType getType() { return WidgetType.CARD; }

    @Override
    public WidgetDefinition build(WidgetRequest request) {
        return WidgetDefinition.builder()
            .id(request.getId())
            .type(WidgetType.CARD)
            .title(request.getTitle())
            .props(request.getProps())
            .build();
    }
}
```

### 4.3 Registry — Widget & Action Registry

```java
public interface WidgetRegistry {
    void register(WidgetRenderer renderer);
    Optional<WidgetRenderer> get(WidgetType type);
    Set<WidgetType> getRegisteredTypes();
}

public interface ActionExecutor {
    ExecuteActionResponse execute(ActionDefinition action,
                                  ActionContext context);
}
```

### 4.4 Composite — Sections Composed of Widgets

```java
public class SectionDefinition {
    private String id;
    private String title;
    private int span;
    private List<WidgetDefinition> widgets;
    // Composition: sections contain widgets
}
```

### 4.5 Command — Action Execution

```java
public interface ActionCommand {
    ExecuteActionResponse execute(ActionDefinition action,
                                  ActionContext context);
}

// For each ActionType, a concrete Command implementation:
//   NavigateActionCommand
//   ApiCallActionCommand
//   RefreshActionCommand
//   ModalActionCommand
//   DeleteActionCommand
//   ExportActionCommand
```

### 4.6 Specification — Filter/Search Specifications

```java
public interface FilterSpecification<T> {
    Predicate<T> toPredicate();
    String toQueryString();  // For backend DB queries
}

public class StatusFilterSpec implements FilterSpecification<User> {
    private final String status;

    public StatusFilterSpec(String status) { this.status = status; }

    @Override
    public Predicate<User> toPredicate() {
        return user -> user.getStatus().equals(status);
    }
}
```

### 4.7 Adapter — External Systems

```java
public interface ExternalSystemAdapter {
    <T> T fetch(String endpoint, Class<T> responseType);
    <T> T execute(String endpoint, Object body, Class<T> responseType);
}
```

---

## 5. JSON Contract Examples

### 5.1 Tab Response

See Section 1.1 above.

### 5.2 Screen Response

See Section 1.2 above.

### 5.3 Action Execution Result

See Section 1.3 above.

### 5.4 Error Response

```json
{
  "code": "VALIDATION_ERROR",
  "message": "Invalid input provided",
  "details": {
    "email": ["Must be a valid email address"],
    "name": ["Must not be empty"]
  },
  "traceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "timestamp": "2026-07-27T18:00:00Z",
  "path": "/admin/screens/users",
  "status": 400
}
```

---

## 6. Recommended Project Structure

### 6.1 Frontend (`src/`)

```
src/
├── types/
│   └── admin-platform.ts          # Contract types (this file)
├── api/
│   ├── admin-client.ts            # HTTP client for admin APIs
│   ├── tabs.ts                    # Tab API functions
│   ├── screens.ts                 # Screen API functions
│   └── actions.ts                 # Action execution
├── components/
│   ├── admin/
│   │   ├── renderer/
│   │   │   ├── ScreenRenderer.tsx
│   │   │   ├── SectionRenderer.tsx
│   │   │   ├── WidgetRenderer.tsx
│   │   │   ├── ActionExecutor.tsx
│   │   │   └── LayoutRenderer.tsx
│   │   ├── registry/
│   │   │   ├── WidgetRegistry.tsx
│   │   │   └── ActionRegistry.tsx
│   │   ├── widgets/
│   │   │   ├── CardRenderer.tsx
│   │   │   ├── StatisticsRenderer.tsx
│   │   │   ├── TableRenderer.tsx
│   │   │   ├── FormRenderer.tsx
│   │   │   ├── ChartRenderer.tsx
│   │   │   ├── ActivityFeedRenderer.tsx
│   │   │   ├── QueryExecutorRenderer.tsx
│   │   │   ├── LogsRenderer.tsx
│   │   │   ├── KPIRenderer.tsx
│   │   │   ├── BannerRenderer.tsx
│   │   │   ├── EmptyStateRenderer.tsx
│   │   │   └── LoadingRenderer.tsx
│   │   └── engine/
│   │       ├── AdminEngine.tsx    # Root rendering engine
│   │       └── ErrorBoundary.tsx
│   ├── reactbits/                 # Existing React Bits components
│   └── ui/                        # Existing shadcn components
├── hooks/
│   ├── useAdminScreen.ts          # Hook to fetch screen definitions
│   ├── useAdminAction.ts          # Hook to execute actions
│   └── useAdminMetadata.ts        # Hook for metadata/permissions
├── screens/
│   └── AdminHomeScreen.tsx        # Minimal entry screen
├── contexts/
│   └── AdminContext.tsx           # Provides admin config to widget renderers
└── styles/
    └── admin-platform.css         # Platform-level admin styles
```

### 6.2 Backend (`com.platform.admin/`)

```
backend/
├── com.platform.admin/
│   ├── AdminApplication.java
│   ├── config/
│   │   ├── SecurityConfig.java
│   │   ├── WebMvcConfig.java
│   │   └── OpenAPIConfig.java
│   ├── controller/
│   │   ├── TabController.java
│   │   ├── ScreenController.java
│   │   ├── ActionController.java
│   │   └── MetadataController.java
│   ├── service/
│   │   ├── TabService.java             # TabProvider interface impl
│   │   ├── ScreenService.java          # ScreenProvider interface impl
│   │   ├── ActionService.java          # ActionExecutor interface impl
│   │   └── MetadataService.java
│   ├── provider/
│   │   ├── TabProvider.java            # Interface
│   │   ├── ScreenProvider.java         # Interface
│   │   └── ActionProvider.java         # Interface
│   │   ├── users/
│   │   │   ├── UsersTabProvider.java
│   │   │   └── UsersScreenProvider.java
│   │   ├── payments/
│   │   │   ├── PaymentsTabProvider.java
│   │   │   └── PaymentsScreenProvider.java
│   │   └── featureflags/
│   │       ├── FeatureFlagsTabProvider.java
│   │       └── FeatureFlagsScreenProvider.java
│   ├── builder/
│   │   ├── ScreenBuilder.java          # Director/Facade
│   │   ├── layout/
│   │   │   └── LayoutBuilder.java
│   │   ├── section/
│   │   │   └── SectionBuilder.java
│   │   ├── widget/
│   │   │   ├── WidgetBuilder.java      # Interface
│   │   │   ├── CardWidgetBuilder.java
│   │   │   ├── TableWidgetBuilder.java
│   │   │   ├── FormWidgetBuilder.java
│   │   │   ├── ChartWidgetBuilder.java
│   │   │   └── QueryExecutorBuilder.java
│   │   └── action/
│   │       ├── ActionBuilder.java      # Interface
│   │       ├── NavigateActionBuilder.java
│   │       ├── ApiCallActionBuilder.java
│   │       └── ModalActionBuilder.java
│   ├── registry/
│   │   ├── WidgetBuilderRegistry.java
│   │   ├── ScreenProviderRegistry.java
│   │   └── ActionHandlerRegistry.java
│   ├── command/
│   │   ├── ActionCommand.java          # Interface
│   │   ├── NavigateActionCommand.java
│   │   ├── ApiCallActionCommand.java
│   │   ├── DeleteActionCommand.java
│   │   └── ExportActionCommand.java
│   ├── specification/
│   │   ├── FilterSpecification.java
│   │   ├── StatusFilterSpec.java
│   │   └── SearchFilterSpec.java
│   ├── strategy/
│   │   ├── PaginationStrategy.java
│   │   ├── CursorPagination.java
│   │   └── PagePagination.java
│   ├── contract/
│   │   ├── dto/
│   │   │   ├── TabResponse.java
│   │   │   ├── ScreenResponse.java
│   │   │   ├── ActionRequest.java
│   │   │   └── ActionResponse.java
│   │   └── mapper/
│   │       ├── ContractMapper.java
│   │       └── WidgetMapper.java
│   └── exception/
│       ├── AdminException.java
│       ├── ContractViolationException.java
│       └── GlobalExceptionHandler.java
```

---

## 7. Class Diagrams (Textual)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Screen (Aggregate Root)                      │
│                                                                 │
│  - id: String                                                    │
│  - title: String                                                 │
│  - description: String                                           │
│  - layout: LayoutDefinition                                      │
│  - sections: List<SectionDefinition>                             │
│  - actions: List<ActionDefinition>                               │
│  - metadata: ScreenMetadata                                      │
│                                                                 │
│  + getSection(id): Section                                       │
│  + getWidget(id): Widget                                         │
│  + getActionsByType(type): List<Action>                          │
└─────────────────────────────────────────────────────────────────┘
         │ 1..*           │ 1..*           │ 0..*
         ▼                ▼                ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────────┐
│   Section    │ │    Widget    │ │    Action        │
│              │ │              │ │                    │
│ - id         │ │ - id         │ │ - id              │
│ - title      │ │ - type       │ │ - type            │
│ - widgets    │ │ - props      │ │ - label           │
│ - actions    │ │ - span       │ │ - variant         │
│ - span       │ │ - visible    │ │ - params          │
└──────────────┘ └──────────────┘ └──────────────────┘
```

---

## 8. Sequence Diagrams

### 8.1 Tab → Screen → Widget Render

```
Browser          AdminEngine           Admin API           Spring Boot
   │                   │                     │                     │
   │── GET /admin/tabs ────────────────────▶│                     │
   │                   │                     │── TabController     │
   │                   │                     │  ──▶ TabService     │
   │                   │                     │  ──▶ TabProvider     │
   │                   │                     │◀── Tab[]            │
   │◀── TabResponse ──────────────────────────────────────────────│
   │                   │                     │                     │
   │── User clicks "Users" ──────────────────▶│                     │
   │                   │                     │                     │
   │── GET /admin/screens/users ─────────────▶│  GET /admin/        │
   │                   │                     │  screens/users      │
   │                   │                     │── ScreenController  │
   │                   │                     │  ──▶ UsersProvider   │
   │                   │                     │  ──▶ UsersScreenBuilder│
   │                   │                     │  ──▶ WidgetBuilders │
   │                   │                     │  ──▶ ActionBuilders │
   │                   │                     │◀── ScreenDefinition │
   │◀── Screen JSON ──────────────────────────────────────────────│
   │                   │                     │                     │
   │── Renders tabs    │                     │                     │
   ├─────────────────────────────────────────────────────────────►│
   │  ┌─ Tab[] ──────────────────────────────────────────────────┐│
   │─▶│ ScreenRenderer │ LayoutRenderer │ SectionRenderer       ││
   │  └───────────────────────────────────────────────────────────┘│
   │                   │                   │                     │
   │── Renders widget  │── WidgetRenderer │                     │
   │   (TABLE type)    │  ──▶ TableRenderer (from registry)     │
   ├─────────────────────────────────────────────────────────────►│
   │                   │                   │                     │
   │── User clicks "Delete Row"─────────────────────────────────▶│
   │                   │── ActionExecutor ──▶ POST /admin/       │
   │                   │                   │  actions/delete     │
   │                   │                   │── ActionController  │
   │                   │                   │  ──▶ DeleteCommand  │
   │                   │                   │  ──▶ DB Delete      │
   │                   │                   │◀── ExecuteResponse  │
   │◀── Refresh screen ─────────────────────────────────────────│
```

### 8.2 Adding a New Widget Type (Extensibility)

```
Backend Team                           Frontend Team
   │                                      │
   │  1. Define WidgetType enum value     │
   │  2. Implement WidgetBuilder          │
   │  3. Implement WidgetRenderer         │
   │  4. Register in WidgetRegistry       │
   │  5. Deploy backend                   │
   │                                      │
   └──────────────────────────────────────┘
                                          │
   1. WidgetRegistry.register()           │
      registers new type                  │
                                          │
                                          │  Frontend auto-
                                          │  renders new widget
                                          │  when contract arrives
                                          │  from backend
                                          │
                                          └────────────────────▶
                                              No frontend changes
                                              needed!
```

---

## 9. Extensibility Patterns

### 9.1 New Widget Type
1. Add type to `WidgetType` enum
2. Implement `WidgetBuilder` for backend
3. Implement `WidgetRenderer` (React component) on frontend
4. Register both in respective registries
5. **Zero other file changes required**

### 9.2 New Action Type
1. Add type to `ActionType` enum
2. Implement `ActionCommand` on backend
3. Implement action handler on frontend
4. Register in `ActionHandlerRegistry` (frontend) and `ActionExecutor` (backend)

### 9.3 New Layout Type
1. Add type to `LayoutType` enum
2. Implement `LayoutBuilder` on backend
3. Implement `LayoutRenderer` on frontend
4. Register in registries

### 9.4 Feature Flags & Role-Based Visibility
- Use `WidgetDefinition.visible` and `WidgetDefinition.permission`
- Use the `VisibilityRule` contract for conditional rendering
- Backend controls visibility via `admin.metadata.features` and `admin.metadata.permissions`

### 9.5 Drag-and-Drop Layouts
- The `LayoutDefinition` is JSON — it can be dynamically generated
- Store user-preferred layouts in a `user_preferences` table keyed by `user_id + tab_id`
- `GET /admin/screens/{tabId}?layout=custom` returns the user's custom layout

### 9.6 Dashboard Personalization
- Same as 9.5 — the screen definition is dynamic and user-scoped

---

## 10. Backward Compatibility Rules

1. **Never remove** a `WidgetType` — deprecate only
2. **Always add** optional fields before required fields in contracts
3. **Unknown widget types** should render as `EmptyState` (graceful degradation)
4. **Unknown action types** should be silently ignored (log warning)
5. **Missing fields** in widget props should use `defaultProps` from renderer
6. **Version the screen** via `screen.metadata.version` — client can check compatibility
7. **TTL on screen responses** — `GET /admin/screens` includes `cache-control` and `ttl` hint

---

## 11. Frontend Component Mapping

Every backend response maps to a reusable frontend component. No admin-specific components exist — only generic renderers.

### 11.1 Navigation Flow → Component Mapping

```
Browser                          Frontend Engine                Backend API
│                                      │                           │
│  GET /admin/navigation               │                           │
│─────────────────────────────────────▶│──── GET /admin/navigation─▶│
│◀─────────────────────────────────────│◀── TabResponse            │
│                                      │                           │
│  Renders Tab[] via .admin-tab-bar    │  (inline in AdminLayout)  │
│                                      │                           │
│  User clicks tab                     │                           │
│                                      │                           │
│  GET /admin/navigation/{tab}/sidebar │                           │
│─────────────────────────────────────▶│──── GET sidebar──────────▶│
│◀─────────────────────────────────────│◀── NavItemResponse        │
│                                      │                           │
│  Renders NavItemData[] via           │                           │
│  <LineSidebar> (react-bits)         │                           │
│                                      │                           │
│  User clicks sidebar item            │                           │
│                                      │                           │
│  GET /admin/navigation/{tab}/        │                           │
│       sidebar/{item}/page            │                           │
│─────────────────────────────────────▶│──── GET page─────────────▶│
│◀─────────────────────────────────────│◀── Screen                 │
│                                      │                           │
│  Renders Screen via                  │                           │
│  <DynamicPage screen={...}>         │                           │
│                                      │                           │
│  ┌─ Screen.sections                  │                           │
│  │  └─ SectionDefinition.widgets     │                           │
│  │     ├─ type: "table" → DynamicTable                          │
│  │     │  └─ props.columns → rendered headers                   │
│  │     │  └─ props.dataSource → fetched data                    │
│  │     ├─ type: "card"  → DynamicCard                           │
│  │     ├─ type: "statistics" → DynamicCard                      │
│  │     ├─ type: "empty-state" → EmptyState                      │
│  │     └─ type: "loading-state" → LoadingState                  │
│  └───────────────────────────────────────────────────────────────│
```

### 11.2 Component → Backend Contract Mapping

| Frontend Component | Backend Response | Key Fields Used |
|---|---|---|
| `AdminLayout` (orchestrator) | `TabResponse` (from `GET /admin/navigation`) | `tabs[]`, `defaultTab` |
| `CardNav` (react-bits) | `NavItemResponse` (from `GET /admin/navigation/{tab}/sidebar`) | `items[]` mapped to `links[]` with `onClick` |
| `LineSidebar` (react-bits) | `NavItemResponse` (same endpoint) | `items[]` → `labels[]`, `activeIdx` |
| `DynamicPage` | `Screen` (from `GET /admin/navigation/{tab}/sidebar/{item}/page`) | `title`, `description`, `sections[]`, `layout` |
| `DynamicTable` | `WidgetDefinition` where `type === "table"` | `props.columns[]`, `props.dataSource`, `props.pagination`, `props.searchable` |
| `DynamicCard` | `WidgetDefinition` where `type === "card" \| "statistics" \| "kpi"` | `title`, `description`, `props.content`, `props.icon` |
| `EmptyState` | `WidgetDefinition` where `type === "empty-state"` | `title`, `description` |
| `LoadingState` | `WidgetDefinition` where `type === "loading-state"` | — |

### 11.3 DynamicTable — Data Fetching Contract

The `DynamicTable` component reads `widget.props.dataSource` to determine how to fetch data:

```json
{
  "type": "table",
  "props": {
    "columns": [
      { "key": "name", "header": "Name", "sortable": true },
      { "key": "email", "header": "Email" },
      { "key": "role", "header": "Role" },
      { "key": "createdAt", "header": "Created", "renderer": "date" }
    ],
    "dataSource": {
      "endpoint": "/api/admin/users",
      "method": "GET",
      "pageParam": "page",
      "sizeParam": "size",
      "sortParam": "sort",
      "dirParam": "dir",
      "searchParam": "q"
    },
    "searchable": true,
    "searchPlaceholder": "Search users...",
    "emptyMessage": "No users found.",
    "pageSizeOptions": [10, 25, 50, 100]
  }
}
```

**Response formats supported by DynamicTable:**

1. **Array** — `[ { "id": 1, ... }, ... ]` (no pagination)
2. **Paginated object** — `{ "data": [...], "total": 1284, "page": 1, "pageSize": 10 }`
3. **Rows object** — `{ "rows": [...], "total": 1284, "page": 1, "pageSize": 10 }`

The component merges pagination, sort, and search query parameters onto the endpoint URL
using the param names defined in `dataSource`.

### 11.4 State Handling per Component

| State | DynamicPage | DynamicTable | DynamicCard |
|---|---|---|---|
| **Loading** | Renders `<LoadingState />` | Skeleton rows with pulse animation | N/A (parent handles) |
| **Error** | Renders `<EmptyState title="Unable to load page" />` | Error message centered | N/A (parent handles) |
| **Empty** | Renders `<EmptyState title="No page definition" />` | Empty message in table body | Renders card body |
| **Edge case** | Missing sections → empty page | Missing columns → empty table | Missing content → empty card |

### 11.5 Extensibility — Adding a New Widget Type

1. Backend returns a `WidgetDefinition` with a new `type` value
2. Add a case to the `renderWidget()` switch in `DynamicPage.tsx`
3. Create the new `Dynamic*` component
4. Export it from `src/components/admin/dynamic/index.ts`
5. **No page-specific code changes required** — existing pages render new widgets automatically

---

*Generated 2026-07-28 — This contract is the single source of truth. Backend and frontend teams must keep in sync.*
