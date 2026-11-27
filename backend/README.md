# FieldOps Pro API

Production-oriented Express/TypeScript API with PostgreSQL, Prisma, rotating JWT refresh sessions, tenant isolation and RBAC.

## Local setup

1. Copy `.env.example` to `.env` and replace every secret.
2. Start PostgreSQL: `docker compose up -d postgres`.
3. Install and generate: `npm install && npm run prisma:generate`.
4. Create the initial migration: `npm run prisma:migrate -- --name initial`.
5. Start: `npm run dev`. Swagger is at `http://localhost:4000/docs`.

Flutter defaults to safe mock mode. Run against this API only after migration/seed setup:

```bash
flutter run --dart-define=USE_MOCKS=false --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1
```

## Security and deployment

- Use separate 32+ byte access/refresh secrets from a secret manager.
- Set a separate 32+ byte `AADHAAR_HASH_SECRET`. The API persists only a keyed
  fingerprint and last four digits; raw Aadhaar values must never be logged or
  stored.
- Put the API behind TLS and a reverse proxy; restrict CORS to deployed clients.
- Run `prisma migrate deploy` during deployment before starting the immutable container.
- Use managed PostgreSQL with encryption, backups and point-in-time recovery.
- Configure object storage, signed URLs, malware scanning, FCM, and payment webhook secrets before enabling those endpoints.
- Camera-only selfie capture is submitted for human review; it is not automatic biometric liveness. Integrate an approved KYC/liveness provider before enabling automatic approval.
- FCM delivery is disabled safely when credentials are absent. Set `FIREBASE_PUSH_ENABLED=true` and provide either `FIREBASE_SERVICE_ACCOUNT_JSON`, the three `FIREBASE_PROJECT_ID`/`FIREBASE_CLIENT_EMAIL`/`FIREBASE_PRIVATE_KEY` values, or opt in to Application Default Credentials. Dispatch pushes only after the notification database transaction commits.
- Payment order/verification routes intentionally return `501` until a provider is configured. Never enable them without webhook signature verification and idempotency tests.

## Status

Implemented: schema, authentication/login/register/rotation/logout, tenant/RBAC middleware, services, bookings, technician self-owned eKYC/application, redacted nearby opportunities with atomic self-claim, progress/earnings, technician job ownership and transitions, availability, eligible-technician database/FCM notifications, admin dashboard/jobs/assignment, invoice listing, errors, rate limiting and Swagger.

Integration seams still requiring external services: password email delivery, S3-compatible uploads, route provider, FCM, payment provider, PDF rendering and provider-specific webhook verification. No successful response is returned for unconfigured financial operations.
