# FieldOps Pro

Premium, responsive Flutter foundation for an AI-assisted field-service SaaS. It ships with functional mock flows for Customer, Technician, and Manager roles, so it can be demonstrated before a backend exists.

## Run

```bash
flutter pub get
flutter run
```

Select a role on sign-in to enter its dedicated, permission-scoped workspace. Demo credentials are prefilled; any valid email and a six-character password work.

## Architecture

Features follow `data`, `domain`, and `presentation` boundaries. Presentation uses `flutter_bloc` events/states and Equatable; dependencies are registered through GetIt. `MockAuthRepository` is deliberately replaceable by a Dio-backed repository. `ApiClient` reads `API_BASE_URL` from `--dart-define`, centralizes headers/errors, and provides the refresh-token interception seam.

```
lib/
  app/                 application, DI, GoRouter routes
  core/                tokens, reusable components, networking
  features/
    auth/ booking/ jobs/ tracking/ invoice/ profile/
    customer/ technician/ admin/
```

## Backend integration

Provide `--dart-define=API_BASE_URL=https://api.example.com`; replace mock repositories with endpoint implementations such as `/auth/login`, `/bookings`, `/jobs`, `/tracking`, and `/invoices`. Secure token persistence and offline sync can be attached at the repository boundary without changing screen code.

The Node/PostgreSQL service now lives in `backend/`. Flutter keeps `USE_MOCKS=true` by default for offline demonstrations. To use real authentication against a running local API:

```bash
flutter run --dart-define=USE_MOCKS=false \
  --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1
```

See `backend/README.md` for database migration, security, Swagger, testing, and deployment instructions. Do not disable mock mode until PostgreSQL migrations and required seed users have been created.

## SaaS web platform

The responsive marketing site and browser-based management dashboard live in
`saas-web/`. They are intentionally separate from Flutter's generated `web/`
platform directory and reuse the versioned Node API rather than duplicating
business rules.

```bash
cd saas-web
python3 -m http.server 4173 --directory dist
```

Open `http://localhost:4173`. The public dashboard starts in labelled demo
mode; use **Connect API** to authenticate against the existing `/api/v1`
backend. Configure the deployed dashboard origin in `CORS_ORIGINS` before
enabling a remote API.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
