# Platform

Monorepo that orchestrates two independent repositories as git submodules.

## Structure

| Path        | Repo (remote)                  | Stack                  | Port |
|-------------|--------------------------------|------------------------|------|
| `backend/`  | `platform_be` (submodule)      | Spring Boot / Gradle   | 8080 |
| `frontend/` | `platform_fe` (submodule)      | Vite + React (TS)      | 3002 |
| `docs/`     | this repo                      | Shared documentation   | -    |

The frontend dev server proxies `/api` to `http://localhost:8080`, so both must run together.

## First-time setup

```sh
git submodule update --init --recursive
npm install                     # root tooling (concurrently)
npm --prefix frontend install   # frontend deps
```

## Run both servers

```sh
npm run dev       # both in ONE terminal, interleaved logs with colored prefixes
npm run dev:logs  # both in background -> logs\*.log, then tail both live
npm run logs      # tail existing logs without starting servers
```

## Logs

| File                   | Source                          |
|------------------------|---------------------------------|
| `logs/backend.log`     | Spring Boot (:8080)             |
| `logs/frontend.log`    | Vite dev server (:3002)         |

## Docs

Shared docs live in [`docs/`](docs/README.md) — API contracts, migrations, and architecture
notes used by both backend and frontend. The `docs/` folders inside `backend/` and `frontend/`
were consolidated here.
