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


Let me design a comprehensive ERP API structure for you.
  ::view-transition-group(*),
  ::view-transition-old(*),
  ::view-transition-new(*) {
    animation-duration: 0.25s;
    animation-timing-function: cubic-bezier(0.19, 1, 0.22, 1);
  }
VvisualizeVvisualize show_widgetHere's the complete breakdown of every domain:
Multi-tenancy model — each registered client (school, dance studio, yoga center, institute) is a tenant. Every API call scopes data to that tenant automatically via the JWT. Different admins get different roles (tenant_admin, staff, finance_manager, etc.) and only see their own data.
The 12 domains and what they cover:
/erp/auth — login, logout, token refresh, password reset for tenant users
/erp/tenants — register a new client org, manage their users and roles, upgrade plans
/erp/members — students, clients, dancers, yoga students — enroll them in courses, track their payments and docs
/erp/staff — teachers, instructors, employees — schedules, leave, payslips
/erp/courses — classes, programs, batches — publish them, manage who's in them
/erp/schedule — timetable slots, rooms, conflict detection, bulk timetable generation
/erp/attendance — mark single or bulk, session-level reports, member/staff history
/erp/finance — fee plans, invoices, payments, refunds, revenue reports
/erp/payroll — salary structures, run payroll, approve payslips
/erp/inventory — equipment, supplies, assign/return assets, low-stock alerts
/erp/communications — send SMS/email, templates, bulk campaigns
/erp/admissions — lead pipeline, enquiries, convert to members, application status
/erp/certificates — issue and verify completion certificates, bulk issue, PDF download
/erp/reports — cross-domain analytics, export to CSV/PDF/XLSX
/erp/settings — per-tenant branding, timezone, currency, third-party integrations
Want me to start building any of these services, or generate the full OpenAPI/Swagger spec?