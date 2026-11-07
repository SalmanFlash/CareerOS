# Local milestone cost audit

| Component used | Operation | Billing required | Data and limits |
| --- | --- | --- | --- |
| Flutter SDK and Dart | Local compilation and UI | No | Uses installed tools and free packages. |
| Node.js | Local preview and offline packaging | No | Preview server binds to 127.0.0.1. |
| Browser storage and service worker | Missions, preferences and offline shell | No | Saved in the current profile. Storage availability and retention depend on browser settings. |
| Greenhouse Job Board API | User-triggered public GET requests for five employer boards | No | No API key, account, application submission or private mission data. Requests time out after 12 seconds and failed boards retain their last successful timestamp. |

The public listing endpoints and authentication rules are documented in the [Greenhouse Job Board API](https://docs.greenhouse.io/job-board). Live availability depends on each employer keeping its board public.

The local build uses deterministic guidance. No hosted backend, paid model, account credential, analytics integration or paid fallback is configured. Verify pricing, permissions, quota limits and failure behavior separately before connecting any provider.
