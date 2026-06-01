# Aimesig ERP — Flutter App

A full-featured Flutter mobile app for the Aimesig ERP, connecting to **https://api.aimesig.com**.

## Architecture

```
lib/
├── main.dart
├── core/
│   ├── api/
│   │   ├── api_constants.dart      ← All endpoint URLs
│   │   └── dio_client.dart         ← Dio + JWT interceptor + token refresh
│   ├── models/
│   │   └── user_model.dart
│   ├── router/
│   │   └── app_router.dart         ← GoRouter + MainShell (bottom nav)
│   └── theme/
│       └── app_theme.dart          ← Brand colours + Material 3 theme
└── features/
    ├── auth/
    │   ├── auth_service.dart        ← login / register / logout
    │   └── presentation/screens/
    │       ├── login_screen.dart
    │       └── register_screen.dart
    ├── dashboard/
    ├── members/
    ├── courses/
    ├── attendance/
    ├── finance/
    ├── admissions/
    ├── staff/
    └── schedule/
```

## API Endpoints covered

| Module     | Service file                  | Endpoints |
|------------|-------------------------------|-----------|
| Auth       | `auth_service.dart`           | POST /erp/auth/login, /register, /refresh |
| Members    | `members_service.dart`        | CRUD + enrollments + payments |
| Courses    | `courses_service.dart`        | CRUD courses + batches + members |
| Attendance | `attendance_service.dart`     | mark, bulk-mark, session, member history, report |
| Finance    | `finance_service.dart`        | fee-plans, invoices, payments, revenue report, outstanding |
| Admissions | `admissions_service.dart`     | leads CRUD, pipeline, convert-to-member |
| Staff      | `staff_service.dart`          | CRUD + schedule |
| Schedule   | `schedule_service.dart`       | slots CRUD + conflict detection |

## Setup

```bash
flutter pub get
flutter run
```

## Auth flow

1. Token stored securely via `flutter_secure_storage`
2. Every request automatically attaches `Authorization: Bearer <token>`
3. On 401, the Dio interceptor silently calls `/erp/auth/refresh`, saves the new token, and retries
4. On refresh failure, token is cleared and GoRouter redirects to `/auth/login`

## Navigation

8-tab bottom navigation (Material 3 `NavigationBar`):  
Dashboard → Members → Courses → Attendance → Finance → Admissions → Staff → Schedule

## Key dependencies

- **dio** — HTTP client
- **go_router** — declarative navigation
- **flutter_secure_storage** — encrypted JWT storage
- **fl_chart** — revenue / attendance charts
- **shimmer** — loading skeletons
