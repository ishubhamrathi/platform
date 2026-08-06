# Migrations

All schema changes live in `src/main/resources/db/migration/` as Flyway SQL files.

## Layout

- **V1–V12**: one file per table, applied in creation order. Each table gets a single
  migration with its PK, a functional UNIQUE index where needed, and minimal extra indexes
  (the over-indexing problem from the old V1–V44 history was removed).
- A fresh database runs V1–V12 cleanly and ends up with the consolidated schema.

```text
V1__Create_User_Table.sql
V2__Create_Question_Sheet_Table.sql
V3__Create_Portfolio_Projects_Table.sql
V4__Create_Blog_Posts_Table.sql
V5__Create_Assets_Table.sql
V6__Create_Notes_Table.sql
V7__Create_Api_Access_Rules_Table.sql
V8__Create_Project_Api_Keys_Table.sql
V9__Create_Feature_Flags_Table.sql
V10__Create_Socials_Table.sql
V11__Create_Inbox_Table.sql
V12__Create_Books_Table.sql
```

## Why existing databases do NOT pick up V1–V12

The app sets `spring.flyway.validate-on-migrate: false`. Flyway tracks the maximum applied
version in `flyway_schema_history`. An existing database still carries the old V1–V44
history, so its max applied version (44) is **higher** than the rewritten V1–V12 files.
Flyway therefore applies nothing — the rewritten files are intentionally ignored, and the
schema stays on the old (still functional) shape.

**Consequence: any new migration must be numbered V45 or higher** to be picked up by an
existing database (a version below the max applied is ignored). The timeline/notification
tables introduced after the consolidation are V45–V49 for this reason.

This is deliberate: it lets existing databases keep running without a destructive reset.

## Applying the consolidated schema to an existing database (one-time reset)

> Only needed if you actually want the rewritten V1–V12 schema (e.g. the new
> `api_access_rules.http_methods` column, dropped legacy columns, minimal indexes).

Because the V1–V12 files recreate tables with the same names, they cannot run over the
existing schema — Flyway would fail with "table already exists". Reset requires dropping
the schema, so **back it up first**.

1. Backup the `platform` schema:
   ```sql
   pg_dump --schema=platform --format=plain -f platform_backup.sql <db-url>
   ```
2. Drop and recreate the schema (this destroys ALL data in the `platform` schema):
   ```sql
   DROP SCHEMA platform CASCADE;
   CREATE SCHEMA platform;
   ```
3. Deploy the app. On startup Flyway runs V1–V12 on the empty schema and writes a fresh
   `flyway_schema_history`. jOOQ codegen then regenerates `src/generated/java` from the new
   schema.

Do NOT add a `V13__Reset_Flyway_History.sql` migration: on a fresh database it would wipe
the just-applied V1–V12 history, causing Flyway to re-run them on the next startup and fail.
The reset is an operator-run, documented procedure only.

## Adding a new migration

1. Add `V<next>__<Description>.sql`. `next` must be **higher than the max version already
   applied to the live DB** (currently **45+**, since the live DB sits at V44). Existing
   migrations (V1–V12) were consolidated one-file-per-table and are below the max, so they
   are intentionally ignored on existing databases.
2. It will be picked up by Flyway on the next startup for all environments (existing DBs
   included).
3. If new jOOQ generated types are needed, the build regenerates them from the live schema.
