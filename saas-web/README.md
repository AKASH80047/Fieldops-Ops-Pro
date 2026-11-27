# FieldOps Pro SaaS Web

Responsive marketing site and browser-based operations dashboard for FieldOps Pro.

## Local preview

```bash
cd saas-web
python3 -m http.server 4173 --directory dist
```

The dashboard starts in clearly labelled demo mode. Choose **Connect API** to use the existing FieldOps Pro REST API. The browser client defaults to `/api/v1`; a different API base URL can be saved from the connection dialog.

## API contracts reused

- `POST /auth/login`
- `GET /admin/dashboard`
- `GET /admin/jobs`
- `GET /services`
- `GET /invoices`
- `GET /notifications`

No backend business rules are duplicated. Demo data is presentation-only and is automatically replaced when an authenticated API connection succeeds.
