# AgroBid Admin

Flutter Web admin panel for the AgroBid grain marketplace. It uses the AgroBid FastAPI backend (`/api/v1/admin/...`) for every screen.

| Page | What admins do there |
|---|---|
| Dashboard | User and marketplace counts, pending reviews, recent registrations |
| Verification queue | Identity submissions waiting for review, oldest first |
| Users | Search and filter farmers and buyers |
| User detail | Approve, reject, suspend, activate; view, approve and reject each document; approve, reject or revoke verification; edit profile; view or remove photo |
| Listings | All grain listings; detail with bids, benchmark and history; remove a listing |
| Bids | All bids, filtered by status or buyer |
| Official prices | Add, edit and delete prices; import a CSV; price history chart |
| Audit log | Every admin action, including each document view |

## Run

```powershell
flutter pub get
flutter run -d edge --web-port 8080
```

By default the panel talks to the live API at `https://agrobidbackend.vercel.app`. To use a local backend:

```powershell
flutter run -d edge --web-port 8080 --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Port 8080 matters: the backend only accepts browser requests from origins listed in its `FRONTEND_ORIGINS` setting, and `http://localhost:8080` is on that list.

Sign in with an admin account. Create one on the backend with `python -m scripts.create_admin`.

## Build and deploy

```powershell
flutter build web --release
```

Upload the `build/web` folder to any static host (Firebase Hosting, Netlify or Vercel). The app uses clean URLs such as `/users/123`, so the host must serve `index.html` for every path:

- Netlify: add `build/web/_redirects` with `/*  /index.html  200`
- Vercel: add a rewrite of `/(.*)` to `/index.html`
- Firebase: `"rewrites": [{"source": "**", "destination": "/index.html"}]`

Then add the deployed address (for example `https://agrobid-admin.netlify.app`) to `FRONTEND_ORIGINS` on the backend, separated by a comma. Until then the browser blocks every API call from that address.

## Code layout

```
lib/
  core/api.dart       Dio client: auth header, automatic token refresh, error messages, uploads, file downloads
  core/session.dart   Admin login, logout and stored session
  core/router.dart    Routes and the login redirect
  core/format.dart    Dates, numbers, status colours, enum lists
  widgets/            Shell (sidebar), tables, pager, dialogs, protected file viewer
  pages/              One file per screen
```

## Tests

```powershell
flutter test
```

- `pages_render_test.dart` renders every page, at desktop and phone width, with real API responses saved in `test/fixtures`.
- `api_integration_test.dart` makes every admin call against a running backend. It is skipped unless you set `AGROBID_TEST_API` and `AGROBID_TEST_USERS`; see the comment at the top of the file.
