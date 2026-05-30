# @aimesig/api-gateway

**api.aimesig.com** — Central reverse-proxy gateway for all Aimesig microservices.

## Route Map

| Gateway path          | Upstream service          | Auth required | Role guard             |
|-----------------------|---------------------------|:-------------:|------------------------|
| `GET /health`         | Gateway (local)           | ✗             | —                      |
| `/auth/**`            | `AUTH_SERVICE_URL`        | ✗             | — (public)             |
| `/chat/**`            | `CHAT_SERVICE_URL`        | ✓ JWT         | any authenticated user |
| `/erp/**`             | `ERP_SERVICE_URL`         | ✓ JWT         | admin, manager, erp_user |
| `/hrms/**`            | `HRMS_SERVICE_URL`        | ✓ JWT         | admin, hr, hr_manager  |
| `/websites/**`        | `WEBSITES_SERVICE_URL`    | ✓ JWT         | any authenticated user |

## Headers forwarded to upstreams

| Header           | Value                          |
|------------------|--------------------------------|
| `X-Request-ID`   | UUID per request               |
| `X-User-ID`      | JWT `sub` claim                |
| `X-User-Email`   | JWT `email` claim              |
| `X-User-Role`    | JWT `role` claim               |

The `Authorization` header is **stripped** before forwarding (upstreams trust the gateway).

## Quick start

```bash
cp .env.example .env
# Edit .env — set JWT_SECRET and upstream URLs

npm install
npm run dev          # development (ts-node-dev, hot reload)
npm run build && npm start  # production
```

## Docker

```bash
docker compose up --build
```

The gateway runs on port **3000**. Point your reverse proxy / DNS for `api.aimesig.com` to this port.

## Rate limits

| Scope        | Default          |
|--------------|------------------|
| Global       | 200 req / min    |
| `/auth/**`   | 20 req / min     |

Limits are configurable via env vars (`RATE_LIMIT_MAX`, `AUTH_RATE_LIMIT_MAX`, `RATE_LIMIT_WINDOW_MS`).

## Environment variables

| Variable                | Default                          | Description                        |
|-------------------------|----------------------------------|------------------------------------|
| `PORT`                  | `3000`                           | Gateway listen port                |
| `NODE_ENV`              | `development`                    |                                    |
| `JWT_SECRET`            | *(required in prod)*             | Secret for verifying JWTs          |
| `JWT_EXPIRES_IN`        | `7d`                             |                                    |
| `AUTH_SERVICE_URL`      | `http://localhost:4001`          |                                    |
| `CHAT_SERVICE_URL`      | `http://localhost:4002`          |                                    |
| `ERP_SERVICE_URL`       | `http://localhost:4003`          |                                    |
| `HRMS_SERVICE_URL`      | `http://localhost:4004`          |                                    |
| `WEBSITES_SERVICE_URL`  | `http://localhost:4005`          |                                    |
| `ALLOWED_ORIGINS`       | `https://app.aimesig.com,...`    | Comma-separated CORS origins       |
| `RATE_LIMIT_MAX`        | `200`                            | Global req/window                  |
| `AUTH_RATE_LIMIT_MAX`   | `20`                             | Auth route req/window              |
| `RATE_LIMIT_WINDOW_MS`  | `60000`                          | Window in ms                       |

## Project structure

```
src/
├── config/          # Centralised env config
├── middleware/
│   ├── auth.ts      # JWT verification + role guards
│   ├── requestId.ts # X-Request-ID + access logging
│   └── errorHandler.ts
├── routes/
│   ├── auth.ts      # /auth  — public
│   ├── chat.ts      # /chat  — JWT
│   ├── erp.ts       # /erp   — JWT + role
│   ├── hrms.ts      # /hrms  — JWT + role
│   └── websites.ts  # /websites — JWT
├── utils/
│   ├── logger.ts    # Winston logger
│   └── proxy.ts     # http-proxy-middleware factory
└── index.ts         # Express app + server bootstrap
```
